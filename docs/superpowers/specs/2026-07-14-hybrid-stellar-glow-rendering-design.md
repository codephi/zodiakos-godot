# Hybrid Stellar Glow Rendering Design

**Date:** 2026-07-14
**Status:** Approved in design conversation; awaiting written-spec review
**Scope:** Replace per-system 3D nodes with a hybrid 2D and GPU-batched stellar presentation.

## Problem

The deterministic sector generator produces stellar-system data quickly, as demonstrated by
the minimap. The main map is slower because `StarFieldView` currently creates a sector
`Node3D`, one `StarVisual`, one `MeshInstance3D`, and one ownership ring for every rendered
system. At large zoom levels, node creation and individual geometry dominate the time between
sector generation and visibility.

The strategic map only needs to show stars at this scale. It does not need a sphere, collider,
or scene-tree node for every stellar system.

## Goals

- Render the distant map as lightweight, clickable 2D points.
- Render the close map as glowing, subtly pulsating stars in one GPU batch.
- Keep all variations deterministic and derived from generated or cataloged stellar
  properties, never from presentation-only randomness.
- Preserve identical selection and system identity across both representations.
- Materialize glow only for the visible area plus a 50% safety margin on every side.
- Eliminate individual star nodes, meshes, rings, and colliders from the strategic map.
- Keep the procedural universe, catalog, simulation, and presentation separated.
- Remain compatible with Godot 4.7 and the Compatibility renderer.

## Non-goals

- Rendering planets, moons, or internal system orbits on the galactic map.
- Showing each component of a binary or multiple-star system as a separate point.
- Simulating real-time stellar physics in the shader.
- Applying distance-from-Earth attenuation. This is a strategic map, not an observer view.
- Persisting renderer or LOD state in a save game.
- Maintaining visual backward compatibility with the current sphere-based renderer.

## Approved LOD Rules

- At camera zoom `>= 220`, use only the 2D point layer.
- At camera zoom `< 200`, prepare and activate the GPU glow layer.
- For `200 <= zoom < 220`, preserve the current mode. This hysteresis prevents repeated mode
  changes near the threshold; exactly `220` forces the 2D mode.
- The glow coverage rectangle is the visible camera rectangle expanded by 50% of its width on
  the left and right and 50% of its height on the top and bottom. Its resulting dimensions are
  twice those of the visible rectangle.
- The 2D representation remains visible while a replacement glow batch is being prepared.
- Points represented by a published glow batch are suppressed from the 2D layer so a system
  never has two permanent representations.

## Architecture

### Data-only sector streaming

`SectorStreamController` continues to request deterministic `UniverseSector` objects. Its view
target no longer creates visual nodes immediately. Instead, a hybrid view retains the immutable
sector definitions needed by both renderers.

The stream remains responsible for loading, prioritization, unloading, and rebasing. It does
not decide whether a system is shown as a point or glow.

### `HybridStarFieldView`

The hybrid view is the composition boundary for the strategic map. It owns:

- the loaded sector-data cache;
- `StarPointLayer2D`;
- `StellarGlowLayer`;
- `StellarLodCoordinator`;
- `SystemSelectionIndex`.

It retains the current view-facing contract needed by `SectorStreamController`, including
materializing and removing sectors, active-sector statistics, system counts, and rebasing.
Those operations update data and renderer inputs instead of creating one node per system.

### `StellarLodCoordinator`

The coordinator consumes camera zoom, camera global position, viewport aspect, and loaded
sector data. It is a state machine with these states:

- `points_2d`;
- `preparing_glow`;
- `stellar_glow`.

It applies the approved hysteresis rules, calculates the glow coverage rectangle, starts a
new build generation when required, and cancels stale generations after camera or sector-data
changes.

Small camera movements inside the existing safety region do not rebuild the glow batch. A new
generation starts when the visible rectangle approaches the usable inner boundary, the zoom
changes enough to alter coverage, or loaded systems within coverage change.

### `StarPointLayer2D`

The distant renderer is one `Control`/`CanvasItem` drawing all visible systems with `_draw`.
It reuses the coordinate-projection approach proven by the minimap. Points use the generated
system type for color and a bounded, normalized size. It creates no child node per system.

When glow is active, this layer excludes systems covered by the published glow generation.
It remains responsible for displaying systems outside that coverage and for providing a safe
fallback if glow construction fails.

### `StellarGlowLayer`

The close renderer owns one `MultiMeshInstance3D` with one shared quad mesh and one shared
shader material. The fixed top-down camera allows the quad to be aligned with the stellar map
plane without per-frame billboarding work.

Each system is one MultiMesh instance with:

- transform: global map position and display scale;
- instance color: scientifically derived combined color and intensity;
- custom data: pulse phase, visual period, pulse amplitude, and halo parameter.

The layer creates no `StarVisual`, `MeshInstance3D`, ownership ring, collider, or scene node per
system. Ownership and selection indicators will be separate batched overlays when gameplay
requires them.

The shader draws a bright core with a soft radial halo and uses `TIME` plus per-instance custom
data to produce subtle pulsation entirely on the GPU. The presentation remains unshaded and
does not require dynamic lights.

## Scientific Stellar Light Profile

### Source of truth

Pulsation inputs belong to the generated or cataloged stellar model, not the renderer.
`StellarLightProfileService` converts a `StellarSystemComposition` into an immutable
`SystemLightProfile`.

Procedural systems obtain their stellar components through the existing deterministic
`LoadSystemComposition` path. Catalog systems use cataloged values where present and apply the
same deterministic scientific completion rules only for missing fields.

No renderer calls a random-number generator. Given the same universe identity, catalog, and
system ID, the light profile is identical for all players and runs.

### Per-star physical profile

Each stellar component exposes enough information to derive its light contribution:

- spectral class (`O`, `B`, `A`, `F`, `G`, `K`, or `M`);
- evolutionary stage, initially main sequence, giant, red giant, or white dwarf;
- mass in solar masses;
- effective temperature in kelvin;
- radius in solar radii;
- luminosity in solar luminosities;
- variability class;
- physical variability period;
- fractional variability amplitude.

The initial procedural distributions favor main-sequence and lower-mass stars, while keeping
hot luminous stars rare. Spectral class and evolutionary stage constrain mass and temperature.
Radius and temperature produce luminosity through the Stefan-Boltzmann relationship rather
than independent visual rolls.

Color is derived from effective temperature. Hotter stars trend blue/white and cooler stars
trend orange/red. The implementation uses a bounded temperature-to-linear-RGB conversion and
then applies the existing visual palette only as an accessibility-safe calibration.

### Scientifically coherent variability

Ordinary stars receive very low fractional variation. Physically variable classes, evolved
giants, and unstable stars may receive longer periods and larger amplitudes within the limits
of their generated class. The values are deterministic outputs of the procedural profile.

Physical periods may span impractical real durations. Presentation uses a monotonic logarithmic
time compression into a subtle visual period of 2.5 to 8 seconds. This preserves the ordering
of faster and slower variables without claiming real-time simulation. Stable stars use a
1%-3% visual intensity variation; strongly variable systems are capped at 12% on the strategic
map to preserve readability.

### Unresolved multiple-star systems

Every stellar system is shown as one glow. Its combined profile is calculated as follows:

- combined luminosity is the sum of component luminosities;
- combined color is a luminosity-weighted blend in linear color space;
- display size is a bounded logarithmic mapping of combined luminosity;
- the dominant variable component maximizes variable light contribution;
- observed fractional pulse amplitude is the dominant variable contribution divided by total
  system luminosity, so steady companions dilute the visible pulsation;
- systems without a meaningful variable component retain only their subtle baseline variation.

The strategic map uses normalized intrinsic luminosity. It does not attenuate a system because
of camera position or distance from Sol.

## Incremental Glow Build

The initial build budget is 512 system profiles per frame and is configurable in
`GameSettings`. A build generation contains:

- generation ID;
- immutable coverage rectangle;
- ordered system IDs;
- current build index;
- pending transforms, colors, and custom data;
- timing and error metrics.

The builder resolves profiles incrementally. It publishes the MultiMesh buffer atomically only
after the current generation completes. If the coordinator invalidates the generation, pending
work is discarded and cannot publish stale data.

The old 2D points remain visible until publication. A profile failure affects only that system:
the system remains in 2D, the error is counted, and the rest of the batch completes.

## Selection

`SystemSelectionIndex` is representation-independent. It indexes loaded system IDs and global
map positions by sector. Pointer selection follows this flow:

1. Convert the pointer from screen coordinates to global universe coordinates.
2. Convert a configurable pixel hit radius into world units at the current zoom.
3. Query nearby sector buckets and select the closest system within the radius.
4. Apply a stable system-ID tie break for equal distances.
5. Emit the same system definition whether the visible representation is 2D or glow.

The visual renderer never owns gameplay identity or click handling. No per-system collider is
created.

## Configuration

All tunable values live in `GameSettings` and `config/game_settings.tres`:

- `stellar_lod_glow_enter_zoom = 200.0`;
- `stellar_lod_glow_exit_zoom = 220.0`;
- `stellar_lod_safety_margin_ratio = 0.5`;
- `stellar_glow_profiles_per_frame = 512`;
- selection radius in pixels;
- 2D point-size limits;
- glow-size and halo limits;
- compressed visual-period limits (`2.5` to `8.0` seconds);
- stable and variable pulse-amplitude limits (`0.01`, `0.03`, and `0.12`);
- glow material intensity and accessibility calibration.

Validation requires finite nonnegative values, enter zoom lower than exit zoom, positive build
budget, ordered minimum/maximum ranges, and pulse amplitudes between zero and one. These
presentation settings do not affect universe identity. Physical procedural-model changes do
affect the universe identity/generator version.

## Debug Metrics

The existing debug HUD adds:

- current LOD state;
- visible 2D point count;
- published glow-instance count;
- pending profile count;
- active build-generation ID;
- total and average build time;
- profile failures;
- strategic-map visual node count;
- renderer draw-call metric when exposed reliably by Godot.

These metrics distinguish sector generation time, stellar-profile time, and visual batch-build
time so future performance conclusions are evidence-based.

## Failure and Fallback Behavior

- Missing or invalid catalog fields use deterministic scientific completion rules.
- An invalid procedural physical profile fails validation before reaching the shader.
- A per-system profile failure keeps that system in 2D.
- A batch allocation or shader failure keeps the entire area in 2D and reports one stable HUD
  error rather than retrying every frame.
- A stale generation cannot replace a newer batch.
- An unavailable glow feature never blocks navigation, selection, or sector streaming.

## Testing Strategy

### Domain tests

- Identical universe identity and system input produce identical physical and light profiles.
- Spectral classes respect ordered temperature ranges.
- Temperature maps coherently from red/orange through white to blue.
- Luminosity follows radius and temperature through the Stefan-Boltzmann relationship.
- Stable, giant, and variable classes respect their period and amplitude bounds.
- Multiple-star luminosity, color, dominant variability, and companion dilution are correct.
- Presentation-only settings do not change universe identity; physical-model settings do.

### Application tests

- Glow activates below 200, deactivates above 220, and preserves state in between.
- The safety rectangle is exactly twice the visible width and height.
- Small motion inside the safety region does not rebuild the batch.
- At most 512 profiles are processed per default frame.
- Stale build generations cannot publish.
- Failed profiles remain represented in 2D.
- The 2D layer remains populated until an atomic glow publication.

### Adapter and integration tests

- The glow layer owns one MultiMesh batch and no per-system nodes.
- Instance transforms, colors, and custom data match approved profiles.
- The Compatibility shader parses and renders in a smoke test.
- Selection returns the same system in 2D and glow modes.
- Sector unloading removes data from both representations and the selection index.
- Existing map movement, zoom-to-cursor, minimap, catalog, and streaming tests remain green.

### Performance comparison

A repeatable benchmark loads the same seeded region using the current node renderer and the new
hybrid renderer. It records sector generation time, materialization time, time-to-visible,
visual-node count, glow-instance count, and available draw-call metrics. Acceptance requires:

- no per-system strategic-map nodes;
- bounded incremental work without a multi-frame input stall;
- materially lower materialization time and node count than the current renderer;
- identical system IDs, positions, types, and click results.

## Rollout

The hybrid view replaces the current sphere-based `StarFieldView` directly; no runtime feature
flag or backward-compatible renderer is required. The implementation proceeds in domain,
application, adapter, integration, and benchmark tasks, each test-driven and committed
separately.

## Scientific and Engine References

- [NASA: stellar classification, temperature, color, and Stefan-Boltzmann law](https://science.nasa.gov/universe/glossary/)
- [NASA: types and evolution of stars](https://science.nasa.gov/universe/stars/types/)
- [NASA Webb: temperature and blackbody spectra](https://science.nasa.gov/mission/webb/science-overview/science-explainers/spectroscopy-101-types-of-spectra-and-spectroscopy/)
- [ESA Gaia: variable-star characterization](https://www.esa.int/ESA_Multimedia/Images/2023/10/Gaia_characterises_dynamics_of_10_000_variable_stars)
- [Godot: optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
- [Godot: per-instance MultiMesh custom data](https://docs.godotengine.org/en/stable/tutorials/3d/vertex_animation/animating_thousands_of_fish.html)
- [Godot: renderer feature comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
