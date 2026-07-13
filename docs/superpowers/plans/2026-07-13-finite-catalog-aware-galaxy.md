# Finite Catalog-Aware Galaxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the uniform infinite star field with a finite Milky Way density model whose procedural stellar systems deterministically yield to catalog anchors.

**Architecture:** `UniverseGenerator` remains the facade used by streaming but delegates density, candidate creation and conflict resolution to focused domain services. It receives the already-open `ScientificCatalogRepository` port, so SQLite remains outside the domain. The visual layer still uses `StarVisual`, while every rendered point now has `StellarSystemDefinition` semantics.

**Tech Stack:** Godot 4.7, GDScript, scientific SQLite catalog from Plan 1, central `GameSettings`, native Windows PowerShell tests.

## Global Constraints

- Complete `2026-07-13-scientific-sqlite-catalog.md` first.
- One logical map unit equals one parsec.
- The gameplay plane uses galactocentric `x,y`; `z` remains scientific metadata.
- Catalog systems always survive; procedural candidates inside their exclusion radius are rejected.
- The result depends only on global seed, generator version, catalog version, coordinate model version, configuration snapshot and sector coordinate.
- Do not preserve the previous generated galaxy or star IDs.
- Keep every adjustable value in `config/game_settings.tres` and its typed field and validation in `scripts/config/game_settings.gd`.
- Preserve the user's current camera values and unrelated local edits when changing central settings.
- Keep handwritten files below 1,000 lines; use TDD; commit and push after every task.

---

## File Structure

```text
scripts/domain/universe/stellar_system_definition.gd  One map point
scripts/domain/universe/universe_identity.gd           Versioned deterministic identity
scripts/domain/universe/galactic_density_model.gd      Continuous Milky Way density
scripts/domain/universe/procedural_candidate_generator.gd
scripts/domain/universe/system_collision_resolver.gd
scripts/domain/universe/universe_generator.gd           Facade
scripts/domain/universe/universe_sector.gd              Collection of systems
scripts/application/universe/load_galaxy_sector.gd      Catalog-aware use case
scripts/adapters/godot_view/star_field_view.gd          System-point rendering
scripts/demo/infinite_star_map_demo.gd                  Catalog boot and Sol start
```

### Task 1: Add finite galaxy settings and validation

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify carefully: `config/game_settings.tres`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd`

**Interfaces:**
- Produces the `galaxy_*` fields consumed by `GalacticDensityModel`.
- Renames `universe_minimum_star_distance` to `universe_minimum_system_distance`.

- [ ] **Step 1: Extend the settings test with exact values**

```gdscript
assert_equal(Settings.galaxy_disk_radius_pc, 50000.0, "disk radius")
assert_equal(Settings.galaxy_halo_radius_pc, 60000.0, "halo radius")
assert_equal(Settings.galaxy_disk_scale_length_pc, 2600.0, "disk scale")
assert_equal(Settings.galaxy_bulge_scale_radius_pc, 1000.0, "bulge scale")
assert_equal(Settings.galaxy_bar_half_length_pc, 5000.0, "bar length")
assert_equal(Settings.galaxy_bar_axis_ratio, 0.4, "bar axis ratio")
assert_equal(Settings.galaxy_bar_angle_deg, 27.0, "bar angle")
assert_equal(Settings.galaxy_spiral_arm_count, 4, "spiral arms")
assert_equal(Settings.galaxy_spiral_pitch_deg, 12.5, "spiral pitch")
assert_equal(Settings.galaxy_spiral_arm_width_pc, 500.0, "spiral width")
assert_equal(Settings.galaxy_halo_weight, 0.02, "halo weight")
assert_equal(Settings.galaxy_max_candidate_systems_per_sector, 32, "candidate cap")
assert_equal(Settings.universe_minimum_system_distance, 1.5, "system spacing")
```

Also mutate `invalid.galaxy_bar_axis_ratio = 0.0` and assert the error list grows. Run the focused test and expect parse/property failures.

Change the two stale zoom assertions from `300.0` to `30000.0`; this records the user's existing Inspector decision without changing the production value.

- [ ] **Step 2: Add typed fields and relational validation**

```gdscript
@export_category("Galaxy Shape")
@export var galaxy_disk_radius_pc: float
@export var galaxy_halo_radius_pc: float
@export var galaxy_disk_scale_length_pc: float
@export var galaxy_bulge_scale_radius_pc: float
@export var galaxy_bar_half_length_pc: float
@export var galaxy_bar_axis_ratio: float
@export var galaxy_bar_angle_deg: float
@export var galaxy_spiral_arm_count: int
@export var galaxy_spiral_pitch_deg: float
@export var galaxy_spiral_arm_width_pc: float
@export var galaxy_halo_weight: float
@export var galaxy_max_candidate_systems_per_sector: int
```

Validation requires all lengths and counts positive, `0 < galaxy_bar_axis_ratio <= 1`, `0 <= galaxy_halo_weight <= 1`, and `galaxy_disk_radius_pc < galaxy_halo_radius_pc`.

- [ ] **Step 3: Update only generation fields in the resource**

Add the exact values tested above and add `universe_minimum_system_distance = 1.5`. Keep the existing cluster fields and `universe_minimum_star_distance` temporarily so the branch remains executable until Task 4 replaces all consumers. Leave `camera_max_zoom` and every unrelated current value untouched.

- [ ] **Step 4: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
git add scripts/config/game_settings.gd config/game_settings.tres tests/config/test_game_settings.gd tests/adapters/godot_view/test_map_camera_controller.gd
git commit -m "feat: configure finite Milky Way generation"
git push
```

### Task 2: Model stellar systems instead of isolated stars

**Files:**
- Create: `scripts/domain/universe/stellar_system_definition.gd`
- Modify: `scripts/domain/universe/universe_sector.gd`
- Delete after migration: `scripts/domain/universe/star_definition.gd`
- Create: `tests/domain/universe/test_stellar_system_definition.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `StellarSystemDefinition.new(id, sector, local_position, visual_type, source, owner_sector, priority, generator_version, galactocentric_z_pc)`.
- Changes `UniverseSector.stars` to `UniverseSector.systems`.

- [ ] **Step 1: Write the failing semantic test**

```gdscript
var definition = System.new(
	&"catalog:sol", Coordinate.new(203, 0), Vector2(30.0, 0.0),
	&"yellow", &"catalog", Coordinate.new(203, 0), 0, 2, 20.8
)
assert_equal(definition.id, &"catalog:sol", "system id")
assert_equal(definition.galactocentric_z_pc, 20.8, "scientific z")
var sector = Sector.new(Coordinate.new(203, 0), [definition], 2)
assert_equal(sector.systems.size(), 1, "sector exposes systems")
```

Expected before implementation: missing preload or constructor.

- [ ] **Step 2: Implement the immutable system record**

Copy the defensive getters and copied coordinates from `StarDefinition`, change the class name and terminology, add the read-only `galactocentric_z_pc` field, and keep no Node or SQLite reference.

Update `UniverseSector` to sort `_systems` by `id` and return `_systems.duplicate()` from `systems`.

- [ ] **Step 3: Migrate compilation references temporarily**

Change generator, view and tests from `.stars` to `.systems` and from `StarDefinition` to `StellarSystemDefinition` without changing generation behavior yet. Rename `star_count()` to `system_count()` and HUD label `Stars` to `Systems`.

- [ ] **Step 4: Run the affected non-demo suites and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_generation_foundations.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
git add scripts/domain/universe scripts/adapters/godot_view scripts/demo tests
git commit -m "refactor: model map points as stellar systems"
git push
```

### Task 3: Build the continuous finite Milky Way density model

**Files:**
- Create: `scripts/domain/universe/galactic_density_model.gd`
- Create: `tests/domain/universe/test_galactic_density_model.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `density_at(Vector2) -> float` in `[0,1]`.
- Produces: `contains(Vector2) -> bool`, false at or beyond halo radius.

- [ ] **Step 1: Write behavior tests**

Assert center, bar, arm, solar-neighborhood, halo and exterior samples. Exact invariants:

```gdscript
assert_true(model.density_at(Vector2.ZERO) > model.density_at(Vector2(8150, 0)), "center denser than Sol")
assert_true(model.density_at(Vector2(8150, 0)) > 0.0, "solar region populated")
assert_true(model.density_at(Vector2(55000, 0)) > 0.0, "sparse halo exists")
assert_equal(model.density_at(Vector2(60000, 0)), 0.0, "outer boundary is void")
assert_equal(model.density_at(Vector2(70000, 0)), 0.0, "outside remains void")
assert_true(model.density_at(Vector2(4000, 0)) != model.density_at(Vector2(0, 4000)), "bar is anisotropic")
```

Expected: missing model preload.

- [ ] **Step 2: Implement the composite density**

```gdscript
class_name GalacticDensityModel
extends RefCounted

var settings
func _init(configuration) -> void: settings = configuration
func contains(position: Vector2) -> bool:
	return position.length() < settings.galaxy_halo_radius_pc
func density_at(position: Vector2) -> float:
	var radius := position.length()
	if radius >= settings.galaxy_halo_radius_pc:
		return 0.0
	var disk := exp(-radius / settings.galaxy_disk_scale_length_pc)
	disk *= 1.0 - smoothstep(settings.galaxy_disk_radius_pc * 0.8, settings.galaxy_disk_radius_pc, radius)
	var bulge := exp(-radius / settings.galaxy_bulge_scale_radius_pc)
	var rotated := position.rotated(-deg_to_rad(settings.galaxy_bar_angle_deg))
	var bar_radius := Vector2(
		rotated.x / settings.galaxy_bar_half_length_pc,
		rotated.y / (settings.galaxy_bar_half_length_pc * settings.galaxy_bar_axis_ratio)
	).length()
	var bar := exp(-bar_radius * bar_radius)
	var arms := _spiral_strength(position, radius)
	var clumps := 0.72 + 0.12 * sin(position.x / 700.0) * sin(position.y / 900.0) + 0.08 * sin((position.x + position.y) / 240.0)
	var halo_fade := 1.0 - smoothstep(settings.galaxy_disk_radius_pc, settings.galaxy_halo_radius_pc, radius)
	var halo := settings.galaxy_halo_weight * halo_fade
	return clampf((disk * (0.35 + 0.65 * arms) * clumps + 0.9 * bulge + 0.8 * bar + halo) / 2.7, 0.0, 1.0)
func _spiral_strength(position: Vector2, radius: float) -> float:
	if radius < 500.0:
		return 0.0
	var theta := position.angle()
	var pitch := deg_to_rad(settings.galaxy_spiral_pitch_deg)
	var phase := log(radius / 8150.0) / tan(pitch)
	var strongest := 0.0
	for arm in settings.galaxy_spiral_arm_count:
		var center := phase + TAU * float(arm) / float(settings.galaxy_spiral_arm_count)
		var angular := absf(wrapf(theta - center, -PI, PI))
		var distance := angular * radius
		strongest = maxf(strongest, exp(-0.5 * pow(distance / settings.galaxy_spiral_arm_width_pc, 2.0)))
	return strongest
```

- [ ] **Step 3: Run focused tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_galactic_density_model.gd'
git add scripts/domain/universe/galactic_density_model.gd tests/domain/universe/test_galactic_density_model.gd tests/test_runner.gd
git commit -m "feat: model finite Milky Way density"
git push
```

### Task 4: Version the universe identity and procedural candidates

**Files:**
- Create: `scripts/domain/universe/universe_identity.gd`
- Create: `scripts/domain/universe/procedural_candidate_generator.gd`
- Modify: `scripts/domain/universe/seed_mixer.gd`
- Replace internals: `scripts/domain/universe/universe_generator.gd`
- Replace: `tests/domain/universe/test_universe_generator.gd`

**Interfaces:**
- Produces: `UniverseIdentity.value: int`.
- Produces: `ProceduralCandidateGenerator.candidates_for_owner(SectorCoordinate) -> Array`.
- Consumes: `CatalogMetadata` from Plan 1.

- [ ] **Step 1: Write identity and finite-generation tests**

Assert that changing catalog version, coordinate model version, generator version or seed changes identity. Assert sector `(2000,2000)` outside the halo is empty, the same sector is deterministic, and request order remains irrelevant.

- [ ] **Step 2: Implement `UniverseIdentity`**

Build a canonical string from the exact version values and generation settings, hash it with `HashingContext.HASH_SHA256`, and fold the first seven bytes into a positive 56-bit integer. Include all `galaxy_*`, sector-size, spacing and candidate-cap fields.

- [ ] **Step 3: Implement density-weighted owner candidates**

For each owner sector, sample density at its center, calculate `raw_count = density * galaxy_max_candidate_systems_per_sector`, use deterministic stochastic rounding for its fractional part, and place that many candidates uniformly inside the owner. IDs use:

```text
proc:<generator-version>:<catalog-version>:<owner-x>:<owner-y>:<candidate-index>
```

Priority and visual type derive from `UniverseIdentity.value`, owner coordinate and candidate ID. No global RNG is used.

- [ ] **Step 4: Make `UniverseGenerator` a facade over candidate generation**

The constructor receives `(catalog_repository, configuration = DefaultSettings, seed = null)`, reads metadata once, creates identity and density services, and initially resolves only procedural candidates. Keep `generate_sector(coordinate)` as the streaming-facing method.

After all consumers compile against the new services, remove the deprecated cluster settings and `universe_minimum_star_distance` from `game_settings.gd`, `game_settings.tres` and their validation. Rerun the full settings suite before committing.

- [ ] **Step 5: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
git add scripts/domain/universe tests/domain/universe/test_universe_generator.gd
git commit -m "feat: generate finite versioned stellar systems"
git push
```

### Task 5: Merge catalog anchors with deterministic collision resolution

**Files:**
- Create: `scripts/domain/universe/system_collision_resolver.gd`
- Create: `scripts/application/universe/load_galaxy_sector.gd`
- Modify: `scripts/domain/universe/universe_generator.gd`
- Create: `tests/application/universe/test_load_galaxy_sector.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `LoadGalaxySector.generate_sector(SectorCoordinate) -> UniverseSector`.
- Consumes: `ScientificCatalogRepository.systems_in_bounds(Rect2)`.

- [ ] **Step 1: Write in-memory repository tests**

Use an inert repository subclass returning `catalog:sol` at `(8150,0,20.8)`. Assert:

- Sol appears in sector `(203,0)` at local `(30,0)`.
- Sol retains source `catalog` and scientific `z`.
- A procedural candidate within `universe_minimum_system_distance` is absent.
- Two catalog anchors closer than the minimum both remain.
- Border conflict produces the same winner from either sector request order.

- [ ] **Step 2: Implement collision rules**

`SystemCollisionResolver.resolve(candidates, anchors)` first keeps every catalog anchor. A procedural candidate loses to any anchor inside the minimum distance. Between procedural candidates, lower numeric priority wins, then lexicographically lower ID. Compare candidates from all owner sectors whose points can touch the target margin.

- [ ] **Step 3: Implement the use case**

`LoadGalaxySector.generate_sector()` calculates the target sector's global `Rect2`, grows it by the minimum-distance margin, fetches anchors, converts their positions to target-local coordinates, asks the generator for nearby procedural candidates, resolves conflicts, filters target ownership, and builds `UniverseSector`.

Catalog definitions use priority `-1`, source `catalog`, their stable catalog ID and `galactocentric_z_pc`. Procedural definitions use source `procedural` and `z = 0.0` until Plan 3 generates composition.

- [ ] **Step 4: Run the affected generation suites, then commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_load_galaxy_sector.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_galactic_density_model.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
git add scripts/domain/universe scripts/application/universe tests/application/universe tests/test_runner.gd
git commit -m "feat: anchor procedural sectors to scientific systems"
git push
```

### Task 6: Connect catalog-aware generation to streaming and start at Sol

**Files:**
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/adapters/godot_view/map_camera_controller.gd`
- Modify: `scripts/adapters/godot_view/star_field_view.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- `SectorStreamController.configure(source, view, initial_position)` consumes a source with `generate_sector(SectorCoordinate)`.
- Demo owns repository lifetime and refuses to configure streaming when validation fails.

- [ ] **Step 1: Update integration tests**

Assert the demo opens the catalog, starts in sector `(203,0)`, materializes `catalog:sol`, reports `Systems` in the HUD, and keeps the database read-only. Add a failing fake repository test proving invalid catalog prevents stream configuration.

Replace the stale demo cases that call `apply_zoom_steps(-200)`. For coverage tests, assign `camera.size = 300.0`, call `_refresh_stream_coverage()` explicitly and retain the existing expected radii for that reference zoom. These plans do not redesign extreme-zoom LOD or request full sector enumeration at `30000.0`.

- [ ] **Step 2: Wire repository, validator and use case**

In `_init()`, open `SqliteScientificCatalogRepository`, validate it, create `UniverseGenerator`, wrap it in `LoadGalaxySector`, and configure the stream only after success. Add `MapCameraController.set_logical_position(UniversePosition)`; it copies and normalizes the value, updates the transform and emits `logical_position_changed`. Set it to sector `(203,0)` local `(30,0)` before configuring the stream. Retain the repository as a demo field and close it in `_exit_tree()`.

If validation fails, render one HUD error beginning `CATALOG_INVALID:` and do not create a procedural-only fallback.

- [ ] **Step 3: Rename presentation statistics without changing meshes**

`StarFieldView` continues to instantiate `StarVisual`, but uses metadata key `system_id`, iterates `sector.systems`, and exposes `system_count()` and `sector_signature()`. `SectorStreamController.stats_changed` names its second argument `visible_systems`.

- [ ] **Step 4: Run all automated tests and smoke check**

```powershell
./tools/run_godot_tests.ps1
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --editor --quit-after 5
```

Expected: `TESTS PASSED`, wrapper pass, and smoke exit code `0` without parser or GDExtension errors.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/adapters/godot_view scripts/demo tests/adapters/godot_view tests/demo
git commit -m "feat: stream catalog-aware Milky Way sectors"
git push
```

## Plan 2 Completion Gate

Run catalog validation, full tests and the smoke command. Manually open the main scene and confirm Sol is visible at startup, panning reveals changing density, the outer halo becomes empty, and returning to a sector preserves its signature.
