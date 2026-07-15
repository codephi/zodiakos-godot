# Hybrid Stellar Glow Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-system 3D scene nodes with clickable 2D points at distant zoom and one scientifically driven, subtly pulsating GPU MultiMesh at close zoom.

**Architecture:** Sector streaming retains immutable system data in a `HybridStarFieldView`. A pure LOD policy and budgeted glow-batch builder decide representation; a `StarPointLayer2D` draws distant points, while a single `StellarGlowLayer` publishes per-instance transforms, colors, and procedural physical pulse data. Selection uses a data-only spatial index and never depends on render nodes.

**Tech Stack:** Godot 4.7 Compatibility renderer, typed GDScript, CanvasItem `_draw`, `MultiMeshInstance3D`, spatial shader, existing deterministic system composition and SQLite catalog, native Windows PowerShell tests.

## Global Constraints

- Work only in `C:\Users\phili\Documents\Zodiakos\.worktrees\star-map-engine` using native Windows PowerShell; never use WSL.
- Preserve unrelated Inspector changes, scene UID serialization, generated `.gd.uid` files, and the temporary SQLite DLL.
- Keep every handwritten source and documentation file below 1,000 lines.
- Follow TDD: prove RED, implement the smallest coherent change, prove GREEN, then refactor.
- Put every renderer tuning value in `GameSettings` and `config/game_settings.tres`.
- Keep physical procedural settings in the universe identity; presentation-only LOD and glow settings must not alter identity.
- Never create a node, mesh instance, ring, collider, or material per stellar system.
- Use one glow `MultiMeshInstance3D` for the published close-view generation.
- Enter glow below zoom `200`, force 2D at zoom `220` or above, and preserve the current mode for `200 <= zoom < 220`.
- Expand glow coverage by 50% on every side, producing twice the visible width and height.
- Build at most 512 stellar profiles per frame by default.
- Commit and push each completed task to `origin/codex/star-map-engine`.

---

### Task 1: Central Settings and Pure LOD/Coverage Policy

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Create: `scripts/application/rendering/stellar_lod_policy.gd`
- Create: `tests/application/rendering/test_stellar_lod_policy.gd`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `StellarLodPolicy.new(settings)`, `next_mode(current_mode, zoom) -> StringName`, and `coverage_rect(visible_rect) -> Rect2`.
- Produces presentation settings: `stellar_lod_glow_enter_zoom`, `stellar_lod_glow_exit_zoom`, `stellar_lod_safety_margin_ratio`, `stellar_glow_profiles_per_frame`, `stellar_selection_radius_pixels`, point/glow size ranges, pulse-period range, pulse-amplitude limits, and glow intensity.
- Produces physical settings: `stellar_physics_model_version`, `stellar_spectral_profiles`, `stellar_evolution_stage_weights`, and `stellar_variability_profiles`.

- [ ] **Step 1: Write failing settings and identity tests**

Add assertions for exact approved defaults and validation failures. Duplicate settings, change every presentation field, and assert `UniverseIdentity.value` is unchanged. Add at least one physical-model version field, change it, and assert identity changes.

```gdscript
assert_equal(settings.stellar_lod_glow_enter_zoom, 200.0, "glow entry zoom")
assert_equal(settings.stellar_lod_glow_exit_zoom, 220.0, "glow exit zoom")
assert_equal(settings.stellar_lod_safety_margin_ratio, 0.5, "glow safety margin")
assert_equal(settings.stellar_glow_profiles_per_frame, 512, "profile frame budget")

var presentation = settings.duplicate(true)
presentation.stellar_lod_glow_enter_zoom = 180.0
assert_equal(_identity(presentation).value, _identity(settings).value, "LOD is presentation only")

var physical = settings.duplicate(true)
physical.stellar_physics_model_version += 1
assert_true(_identity(physical).value != _identity(settings).value, "physics model versions identity")

physical = settings.duplicate(true)
physical.stellar_spectral_profiles = physical.stellar_spectral_profiles.duplicate(true)
physical.stellar_spectral_profiles[&"G"]["temperature_min_k"] = 5100.0
assert_true(_identity(physical).value != _identity(settings).value, "spectral model versions identity")
```

- [ ] **Step 2: Write failing LOD and coverage tests**

```gdscript
var policy = StellarLodPolicy.new(settings)
assert_equal(policy.next_mode(&"points_2d", 199.9), &"stellar_glow", "below 200 enters")
assert_equal(policy.next_mode(&"points_2d", 200.0), &"points_2d", "200 preserves")
assert_equal(policy.next_mode(&"stellar_glow", 219.9), &"stellar_glow", "band preserves")
assert_equal(policy.next_mode(&"stellar_glow", 220.0), &"points_2d", "220 exits")
assert_equal(
	policy.coverage_rect(Rect2(100.0, 50.0, 400.0, 200.0)),
	Rect2(-100.0, -50.0, 800.0, 400.0),
	"50 percent per side doubles dimensions"
)
```

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/application/rendering/test_stellar_lod_policy.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: missing fields and policy script.

- [ ] **Step 4: Implement settings, validation, identity routing, and policy**

Declare typed exported fields under `Stellar Rendering` and `Stellar Physics`. Validate finite values, entry `<` exit, margin `>= 0`, positive build budget, ordered ranges, amplitudes in `[0, 1]`, required `O..M` spectral keys, ordered temperature/mass ranges, and normalized positive stage/variability weights. Include the physics model version and canonicalized physical dictionaries in `UniverseIdentity._take_configuration_snapshot` and `_canonical_value`; exclude every presentation field.

```gdscript
func next_mode(current_mode: StringName, zoom: float) -> StringName:
	if zoom < settings.stellar_lod_glow_enter_zoom:
		return &"stellar_glow"
	if zoom >= settings.stellar_lod_glow_exit_zoom:
		return &"points_2d"
	return current_mode

func coverage_rect(visible: Rect2) -> Rect2:
	var growth := visible.size * settings.stellar_lod_safety_margin_ratio
	return visible.grow_individual(growth.x, growth.y, growth.x, growth.y)
```

- [ ] **Step 5: Run focused tests GREEN**

Run Step 3 plus the universe identity suite. Expected: `TESTS PASSED`.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/config/game_settings.gd config/game_settings.tres scripts/domain/universe/universe_identity.gd scripts/application/rendering/stellar_lod_policy.gd tests
git commit -m "feat: add stellar rendering lod settings"
git push origin codex/star-map-engine
```

---

### Task 2: Scientifically Coherent Stellar Light Profiles

**Files:**
- Create: `scripts/domain/universe/stellar_light_profile.gd`
- Create: `scripts/domain/universe/stellar_physics_model.gd`
- Create: `scripts/application/rendering/stellar_light_profile_service.gd`
- Modify: `scripts/domain/universe/procedural_system_factory.gd`
- Create: `tests/domain/universe/test_stellar_physics_model.gd`
- Create: `tests/application/rendering/test_stellar_light_profile_service.gd`
- Modify: `tests/domain/universe/test_procedural_system_factory.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces immutable `StellarLightProfile` fields: `system_id`, `linear_color`, `combined_luminosity_solar`, `display_scale`, `pulse_phase`, `visual_period_seconds`, `pulse_amplitude`, and `halo_strength`.
- Produces `StellarPhysicsModel.new(settings)` and `complete_star_properties(star_id, visual_type, existing_properties, identity) -> Dictionary`.
- Produces `StellarLightProfileService.execute(system_definition) -> StellarLightProfile` and `fallback(system_definition) -> StellarLightProfile`.
- Consumes: existing `LoadSystemComposition.execute(system_definition)` and the universe identity.

- [ ] **Step 1: Write failing physical-model tests**

Cover deterministic output, ordered spectral temperature bands, mass/radius bounds, Stefan-Boltzmann luminosity, physical variability bounds, and no render-time randomness.

```gdscript
var first = model.complete_star_properties(&"same", &"yellow", {}, identity)
var second = model.complete_star_properties(&"same", &"yellow", {}, identity)
assert_equal(first, second, "same procedural inputs produce the same star")
assert_true(first.temperature_k >= 5200.0 and first.temperature_k <= 7500.0, "F/G range")
var expected := pow(first.radius_solar, 2.0) * pow(first.temperature_k / 5772.0, 4.0)
assert_true(is_equal_approx(first.luminosity_solar, expected), "Stefan-Boltzmann ratio")
```

- [ ] **Step 2: Write failing combined-profile tests**

Build synthetic single and binary compositions. Assert summed luminosity, luminosity-weighted linear color, logarithmically bounded size, dominant-variable selection, companion dilution, and visual period compression into `2.5..8.0` seconds.

```gdscript
var profile = service.from_composition(definition, binary_composition)
assert_equal(profile.combined_luminosity_solar, 12.0, "component luminosities sum")
assert_true(profile.pulse_amplitude < primary_fractional_amplitude, "companion light dilutes pulse")
assert_true(profile.visual_period_seconds >= 2.5 and profile.visual_period_seconds <= 8.0, "period compressed")
```

- [ ] **Step 3: Run focused tests RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_stellar_physics_model.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/application/rendering/test_stellar_light_profile_service.gd'
```

- [ ] **Step 4: Implement physical completion**

Use seeded `SeedMixer`/`RandomNumberGenerator` only inside the domain model. Read spectral ranges and stage/variability weights from the identity snapshot created from central settings. Map current visual types to scientifically ordered spectral-class ranges, derive mass and temperature within the class, derive stage with rare evolved outcomes, calculate radius, then calculate luminosity as `R²(T/5772)⁴`. Store these values in procedural star body properties. Preserve catalog mass, radius, temperature, and luminosity when present; complete only absent values.

Required property keys:

```gdscript
{
	"spectral_class": &"G",
	"evolutionary_stage": &"main_sequence",
	"mass_solar": 1.0,
	"temperature_k": 5772.0,
	"radius_solar": 1.0,
	"luminosity_solar": 1.0,
	"variability_class": &"stable",
	"variability_period_days": 25.0,
	"variability_fraction": 0.01,
}
```

- [ ] **Step 5: Implement unresolved-system profile aggregation**

Convert temperature to linear RGB, sum luminosities, blend component colors by luminosity, identify the largest `component_luminosity * variability_fraction`, divide that contribution by total luminosity, clamp presentation amplitude, and derive phase from the physical profile seed. The renderer receives the finished values and never calls an RNG.

- [ ] **Step 6: Run focused and existing composition tests GREEN**

Run Step 3 plus procedural factory and production catalog suites. Expected: all pass.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/domain/universe scripts/application/rendering tests/domain/universe tests/application/rendering tests/test_runner.gd
git commit -m "feat: generate scientific stellar light profiles"
git push origin codex/star-map-engine
```

---

### Task 3: Data-only Hybrid View, 2D Point Layer, and Selection Index

**Files:**
- Create: `scripts/adapters/godot_view/hybrid_star_field_view.gd`
- Create: `scripts/adapters/godot_view/star_point_layer_2d.gd`
- Create: `scripts/application/rendering/system_selection_index.gd`
- Create: `tests/adapters/godot_view/test_hybrid_star_field_view.gd`
- Create: `tests/adapters/godot_view/test_star_point_layer_2d.gd`
- Create: `tests/application/rendering/test_system_selection_index.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `HybridStarFieldView.materialize_sector(sector, origin)`, `remove_sector(coordinate)`, `rebase(origin)`, `active_keys()`, `active_coordinates()`, `active_sector_count()`, `system_count()`, and `sector_signature(coordinate)` preserve the stream contract.
- `HybridStarFieldView.update_camera(camera_global, zoom, viewport_size)` updates projection without creating system nodes.
- `StarPointLayer2D.update_snapshot(systems, camera_global, zoom, viewport_size, suppressed_ids)` accepts immutable arrays/dictionaries and redraws once.
- `SystemSelectionIndex.add_sector(sector)`, `remove_sector(coordinate)`, and `pick(world_position, world_radius)` return a `StellarSystemDefinition` or `null`.

- [ ] **Step 1: Write failing hybrid-view contract tests**

Assert sectors and signatures remain deterministic, unloading preserves sector definitions, `system_count` matches data, rebasing does not mutate global positions, and materializing thousands of systems creates no child per system.

```gdscript
view.materialize_sector(sector, coordinate)
assert_equal(view.active_sector_count(), 1, "sector retained as data")
assert_equal(view.system_count(), sector.system_count(), "system stats preserved")
assert_equal(view.get_child_count(), view.fixed_renderer_child_count(), "no per-system nodes")
```

- [ ] **Step 2: Write failing point-projection and selection tests**

Assert screen mapping at positive and negative sectors, size/color fallback, suppression after glow publication, nearest-hit behavior, stable ID tie-breaks, and removal from the selection index.

- [ ] **Step 3: Run focused tests RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_hybrid_star_field_view.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/application/rendering/test_system_selection_index.gd'
```

- [ ] **Step 4: Implement data-only view and index**

Store active entries as `{coordinate, sector}` only. Calculate global position as `sector * sector_size + local_position`. Bucket selection by sector key and query only buckets touched by the pick radius. Preserve the existing stream-facing method names so `SectorStreamController` needs no branching.

- [ ] **Step 5: Implement the 2D CanvasItem layer**

Create one CanvasLayer/Control pair. In `_draw`, map world positions through the orthographic camera snapshot, draw one circle per visible unsuppressed system, and keep draw state immutable between updates. Handle no input in this component; route clicks through the hybrid view and selection index.

- [ ] **Step 6: Run focused tests GREEN**

Run Step 3 plus existing sector-streaming tests using the new view in a focused compatibility fixture.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/adapters/godot_view/hybrid_star_field_view.gd scripts/adapters/godot_view/star_point_layer_2d.gd scripts/application/rendering/system_selection_index.gd tests tests/test_runner.gd
git commit -m "feat: add data-only hybrid star field"
git push origin codex/star-map-engine
```

---

### Task 4: Budgeted Glow Batch Builder and Compatibility Shader

**Files:**
- Create: `scripts/application/rendering/stellar_glow_batch_builder.gd`
- Create: `scripts/adapters/godot_view/stellar_glow_layer.gd`
- Create: `assets/shaders/stellar_glow.gdshader`
- Create: `tests/application/rendering/test_stellar_glow_batch_builder.gd`
- Create: `tests/adapters/godot_view/test_stellar_glow_layer.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `StellarGlowBatchBuilder.begin(generation_id, coverage, systems)`, `process(limit = -1) -> int`, `cancel()`, `is_complete()`, and `snapshot() -> Dictionary`.
- Snapshot keys: `generation`, `coverage`, `system_ids`, `transforms`, `colors`, `custom_data`, `processed`, `total`, `failures`, `elapsed_ms`.
- `StellarGlowLayer.publish(snapshot)`, `clear()`, `instance_count()`, and `published_generation`.

- [ ] **Step 1: Write failing builder tests**

Use a counting fake profile service. Prove the 512 default budget, explicit smaller budgets, deterministic system order, failed-profile fallback IDs, cancellation, and stale-generation isolation.

```gdscript
builder.begin(7, coverage, systems)
assert_equal(builder.process(3), 3, "explicit budget")
assert_equal(service.calls, 3, "only budgeted profiles resolve")
builder.begin(8, coverage, replacement)
assert_true(builder.snapshot().generation == 8, "new generation replaces pending work")
```

- [ ] **Step 2: Write failing layer tests**

Publish a synthetic snapshot and assert exactly one `MultiMeshInstance3D`, one shared `QuadMesh`, `instance_count` matches, custom data is enabled, transforms/colors/custom values match, clearing removes instances, and no per-system child exists.

- [ ] **Step 3: Run focused tests RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/application/rendering/test_stellar_glow_batch_builder.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_stellar_glow_layer.gd'
```

- [ ] **Step 4: Implement budgeted immutable builder**

Filter systems against coverage, order by string system ID for stable buffer layout, resolve profiles incrementally, and append `Transform3D`, `Color`, and custom `Color(phase, normalized_period, amplitude, halo)` values. Do not touch the scene tree.

- [ ] **Step 5: Implement one MultiMesh and shader**

Configure a 3D MultiMesh with color and custom data before setting `instance_count`. Use one quad aligned to the XZ map plane. The shader must be unshaded, use a radial UV falloff, read `COLOR` and `INSTANCE_CUSTOM`, and calculate subtle intensity modulation from `TIME`.

```glsl
float pulse = 1.0 + sin(TIME * period_scale + INSTANCE_CUSTOM.x * TAU)
	* INSTANCE_CUSTOM.z;
float core = smoothstep(0.22, 0.0, distance(UV, vec2(0.5)));
float halo = smoothstep(0.5, 0.05, distance(UV, vec2(0.5))) * INSTANCE_CUSTOM.w;
ALBEDO = COLOR.rgb * core;
EMISSION = COLOR.rgb * (core + halo) * pulse;
ALPHA = clamp(core + halo, 0.0, 1.0);
```

- [ ] **Step 6: Run focused tests and shader smoke GREEN**

Run Step 3, then boot the demo headlessly for 20 frames and assert no shader parse/runtime error.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/application/rendering/stellar_glow_batch_builder.gd scripts/adapters/godot_view/stellar_glow_layer.gd assets/shaders/stellar_glow.gdshader tests tests/test_runner.gd
git commit -m "feat: add budgeted stellar glow multimesh"
git push origin codex/star-map-engine
```

---

### Task 5: LOD Coordination, Atomic Transition, and Unified Picking

**Files:**
- Create: `scripts/adapters/godot_view/stellar_lod_coordinator.gd`
- Modify: `scripts/adapters/godot_view/hybrid_star_field_view.gd`
- Create: `tests/adapters/godot_view/test_stellar_lod_coordinator.gd`
- Modify: `tests/adapters/godot_view/test_hybrid_star_field_view.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `StellarLodCoordinator.update_camera(camera_global, zoom, viewport_size)`, `notify_data_changed()`, `process_pending(limit = -1)`, `mode`, `generation_id`, and `metrics()`.
- Signals: `points_snapshot_changed(snapshot)`, `glow_snapshot_ready(snapshot)`, `selection_requested(system)`.
- `HybridStarFieldView.pick_screen(screen_position) -> StellarSystemDefinition` converts screen to world and delegates to the selection index.

- [ ] **Step 1: Write failing state-machine tests**

Prove threshold/hysteresis transitions, exact doubled coverage, no rebuild while visible bounds stay inside the safe inner area, rebuild after crossing it, 2D retention while preparing, atomic suppression on publication, and generation cancellation.

- [ ] **Step 2: Write failing unified-picking tests**

Pick the same screen point in `points_2d`, `preparing_glow`, and `stellar_glow`; assert the identical system ID is returned without colliders.

- [ ] **Step 3: Run focused tests RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_stellar_lod_coordinator.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_hybrid_star_field_view.gd'
```

- [ ] **Step 4: Implement coordinator and atomic publication**

Use `StellarLodPolicy` for mode decisions. On entry, start a builder generation and keep points unsuppressed. On completion, publish glow first, then suppress exactly the published IDs. On exit, restore points before clearing glow. Retain the existing generation while the visible bounds remain inside its inner half-margin.

- [ ] **Step 5: Implement screen picking**

Convert pixels to world coordinates with orthographic height and viewport aspect. Convert `stellar_selection_radius_pixels` to world radius with `zoom / viewport_height`. Emit selection through the hybrid view; do not attach input to individual render instances.

- [ ] **Step 6: Run focused tests GREEN**

Run Step 3 and verify no new scene-tree nodes appear when switching LOD repeatedly.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/adapters/godot_view scripts/application/rendering tests/adapters/godot_view tests/test_runner.gd
git commit -m "feat: coordinate hybrid stellar lod and selection"
git push origin codex/star-map-engine
```

---

### Task 6: Demo Integration, Debug Metrics, and Legacy Renderer Removal

**Files:**
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `scripts/adapters/godot_view/streaming_debug_panel.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/adapters/godot_view/test_streaming_debug_panel.gd`
- Delete: `scripts/adapters/godot_view/star_field_view.gd`
- Delete: `scripts/visuals/star_visual.gd`

**Interfaces:**
- Demo composes `HybridStarFieldView` with the existing stream, composition loader, camera, minimap, and catalog.
- Debug metrics include `stellar_lod_mode`, `stellar_points_2d`, `stellar_glow_instances`, `stellar_glow_pending`, `stellar_glow_generation`, `stellar_glow_build_ms`, `stellar_glow_profile_failures`, and `stellar_visual_nodes`.

- [ ] **Step 1: Write failing demo integration tests**

Assert the demo uses `HybridStarFieldView`, shares the existing composition loader, has zero per-system visual nodes, routes camera movement/zoom/resize to the hybrid view, preserves stream counts and minimap independence, and selects the same catalog/procedural system in both LODs.

- [ ] **Step 2: Write failing debug-metric tests**

Feed a synthetic renderer snapshot and assert the debug panel displays mode, 2D count, glow count, pending count, generation, build time, failures, and visual nodes.

- [ ] **Step 3: Run focused tests RED**

```powershell
.\tools\run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
.\tools\run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_streaming_debug_panel.gd'
```

- [ ] **Step 4: Replace demo composition and camera routing**

Instantiate the hybrid view with runtime settings and the existing `composition_loader`. Keep `SectorStreamController` unchanged at its public boundary. Route camera logical position, zoom, and viewport size to `update_camera`. Route clicks to `pick_screen` and expose the resulting system signal for the future information panel.

- [ ] **Step 5: Add renderer metrics and remove legacy visuals**

Extend the existing metrics dictionary/label and enable the centrally configured Environment glow used by the emissive shader. Delete the old sphere renderer only after all tests and imports use the hybrid view. Keep generic visual palette/material helpers used by planets or future UI.

- [ ] **Step 6: Run integration and streaming suites GREEN**

Run Step 3 plus sector streaming, minimap, camera, catalog, and visual-palette suites. Expected: all pass.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/demo scripts/adapters/godot_view scripts/visuals tests
git commit -m "feat: replace star nodes with hybrid glow renderer"
git push origin codex/star-map-engine
```

---

### Task 7: Benchmark and Full Verification

**Files:**
- Create: `tests/performance/test_hybrid_star_renderer_benchmark.gd`
- Modify: `tests/test_runner.gd`
- Update: `docs/superpowers/specs/2026-07-14-hybrid-stellar-glow-rendering-design.md`

**Interfaces:**
- Benchmark emits stable labels for sector generation time, profile time, materialization time, time-to-visible, visual-node count, point count, and glow-instance count.

- [ ] **Step 1: Add repeatable benchmark test**

Use the fixed production seed and the same sector window for data-only and glow paths. Assert IDs and positions are identical, visual system-node count is zero, glow instance count equals published profiles, and materialization completes within a generous non-flaky ceiling while recording comparative metrics.

- [ ] **Step 2: Run all automated tests with versioned defaults**

Temporarily use the committed `camera_max_zoom = 100` and `stream_viewport_grid_size = 3`, run:

```powershell
.\tools\run_godot_tests.ps1
.\tools\run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
```

Expected: `TESTS PASSED`, review checks passed, catalog valid, wrapper passed. Restore the user's Inspector values immediately afterward.

- [ ] **Step 3: Smoke boot and constraint checks**

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
rg -n "StarVisual|MeshInstance3D\.new\(\)|CollisionShape3D|Area3D" scripts/adapters/godot_view scripts/demo
$tooLong = Get-ChildItem scripts,tests,docs -Recurse -File | Where-Object { (Get-Content $_.FullName).Count -gt 1000 }
if ($tooLong) { $tooLong.FullName; exit 1 }
```

Expected: clean smoke boot, no per-system legacy visual construction, and no handwritten file above 1,000 lines.

- [ ] **Step 4: Update spec status and commit benchmark**

Set the design status to implemented, record benchmark measurements without claiming unstable FPS guarantees, then:

```powershell
git add tests/performance/test_hybrid_star_renderer_benchmark.gd tests/test_runner.gd docs/superpowers/specs/2026-07-14-hybrid-stellar-glow-rendering-design.md
git commit -m "test: verify hybrid stellar renderer performance"
git push origin codex/star-map-engine
```

- [ ] **Step 5: Verify preserved user state and remote sync**

Confirm `camera_max_zoom = 1000`, `stream_viewport_grid_size = 10`, scene UID changes, generated `.gd.uid` files, and the temporary SQLite DLL remain outside commits. Assert local and `origin/codex/star-map-engine` SHAs match.
