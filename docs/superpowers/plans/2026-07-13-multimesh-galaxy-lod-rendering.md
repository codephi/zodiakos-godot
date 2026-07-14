# MultiMesh Galaxy LOD Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render detailed systems with bounded MultiMesh batches, render distant aggregate galaxy views without real systems, and permit ID-based picking only in detailed LOD.

**Architecture:** The detail adapter owns canonical sector data and rebuilds a small set of MultiMesh buffers on the main thread. Cluster/overview use deterministic presentation-only points. A coordinator applies the pure LOD policy and enables sector streaming only for detail.

**Tech Stack:** Godot 4.7 Compatibility renderer, MultiMeshInstance3D, GDScript, CPU aggregate generation, existing async task executor.

## Global Constraints

- Plans 1 and 2 must be complete.
- Never create a permanent Node3D/MeshInstance3D hierarchy per system.
- Aggregate points never receive canonical system IDs and are never selectable.
- MultiMesh and SceneTree mutations occur only on the main thread.
- Renderer remains Compatibility; do not add compute shaders.
- Every visual default is configured through `game_settings.tres` or a typed profile.
- Keep handwritten files at or below 1,000 lines.
- Use TDD, commit and push after every task.

---

### Task 1: MultiMesh detailed star field

**Files:**
- Create: `scripts/adapters/godot_view/multimesh_star_field_view.gd`
- Create: `tests/adapters/godot_view/test_multimesh_star_field_view.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `UniverseSector`, render-origin `SectorCoordinate`, central settings
  and the effective `PerformanceProfile`.
- Produces the existing stream-view contract: `materialize_sector`, `remove_sector`, `rebase`, `has_sector`, `active_keys`, `active_coordinates`, `active_sector_count`, `system_count`, `sector_signature`.
- Adds: `set_profile(profile)`, `flush_updates()`,
  `system_definition(system_id)`, `instance_location(system_id)`,
  `all_system_entries()`.

- [ ] **Step 1: Write failing adapter tests**

Build two sectors containing multiple visual types. Assert:

```gdscript
var view = MultiMeshStarFieldView.new(Settings)
view.materialize_sector(_sector(0, 0, [_system(&"a", &"yellow"), _system(&"b", &"red")]), Coordinate.new())
view.flush_updates()
assert_equal(view.system_count(), 2, "definitions are retained")
assert_true(view.get_child_count() <= Settings.universe_visual_types.size(), "only typed batches exist")
assert_equal(view.instance_location(&"a").visual_type, &"yellow", "ID maps to typed batch")
assert_equal(view.system_definition(&"a").id, &"a", "definition maps by ID")
```

Also assert duplicate sector is ignored, remove/rebase mark buffers dirty, exact
instance transforms include sector delta, and no child has `system_id` metadata.
Changing profile must preserve system IDs/transforms, rebuild only shared mesh
presentation, disable emission when `effects_enabled` is false and reduce sphere
segments according to `star_mesh_quality`.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_multimesh_star_field_view.gd'
```

Expected: FAIL because the adapter is missing.

- [ ] **Step 3: Implement batch lifecycle**

Create one `MultiMeshInstance3D` lazily per configured visual type. Each owns one
`MultiMesh` with `TRANSFORM_3D`; its mesh/material come from the shared geometric
star palette. `materialize_sector`, `remove_sector` and `rebase` only change data
and set `_dirty = true`.

`flush_updates()` gathers systems in deterministic `(sector y, sector x, id)`
order, groups by type, sets `instance_count` once per batch, writes transforms and
rebuilds both ID mappings atomically. Empty batches are hidden.

```gdscript
func flush_updates() -> void:
    if not _dirty: return
    var grouped := _group_active_systems()
    var next_locations := {}
    for visual_type in settings.universe_visual_types:
        _write_batch(visual_type, grouped.get(visual_type, []), next_locations)
    _instance_locations = next_locations
    _dirty = false
```

`set_profile` marks presentation batches dirty without changing active sectors.
Map quality levels `1..4` to the existing base mesh settings with
`divisor = 5 - star_mesh_quality`; use at least 4 radial segments and 2 rings.
Quality 4 therefore uses the configured base mesh unchanged. Pass
`effects_enabled` to the shared material factory's emission flag. These are
presentation decisions and must not enter universe identity or system IDs.

- [ ] **Step 4: Preserve public-data immutability**

`all_system_entries()` returns new Dictionaries with stable ID, definition and
render position. Mutating the returned Array or Dictionary must not alter view
state. Domain definitions are already immutable.

- [ ] **Step 5: Run focused/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_multimesh_star_field_view.gd'
./tools/run_godot_tests.ps1
git add scripts/adapters/godot_view/multimesh_star_field_view.gd tests/adapters/godot_view/test_multimesh_star_field_view.gd tests/test_runner.gd
git commit -m "feat: batch detailed stars with multimesh"
git push
```

Expected: PASS.

### Task 2: Spatial picking by system ID

**Files:**
- Create: `scripts/application/projections/system_picking_index.gd`
- Create: `tests/application/projections/test_system_picking_index.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `rebuild(entries: Array)`, `pick(map_position: Vector2, tolerance: float) -> StringName`, `clear()`, `size()`.
- Entry schema: `{ "id": StringName, "position": Vector2 }`.

- [ ] **Step 1: Write failing picking tests**

```gdscript
var index = SystemPickingIndex.new(4.0)
index.rebuild([
    {"id": &"b", "position": Vector2(3.0, 0.0)},
    {"id": &"a", "position": Vector2(1.0, 0.0)},
])
assert_equal(index.pick(Vector2.ZERO, 1.1), &"a", "nearest system is selected")
assert_equal(index.pick(Vector2.ZERO, 0.5), &"", "outside tolerance is absent")
assert_equal(index.pick(Vector2(2.0, 0.0), 2.0), &"a", "ID breaks equal-distance tie")
```

Add negative coordinates, neighboring cells, rebuild replacement and clear.

- [ ] **Step 2: Run RED and implement a grid index**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_system_picking_index.gd'
```

Use `floori(position / cell_size)` for cell keys. Picking searches every cell
intersecting the tolerance radius, compares squared distance and uses lexical ID
as deterministic tie-breaker. Reject nonpositive cell size/tolerance.

- [ ] **Step 3: Run GREEN/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_system_picking_index.gd'
./tools/run_godot_tests.ps1
git add scripts/application/projections/system_picking_index.gd tests/application/projections/test_system_picking_index.gd tests/test_runner.gd
git commit -m "feat: pick detailed systems by position"
git push
```

### Task 3: Deterministic presentation-only galaxy aggregates

**Files:**
- Create: `scripts/application/projections/galaxy_aggregate_point.gd`
- Create: `scripts/application/projections/galaxy_aggregate_generator.gd`
- Create: `tests/application/projections/test_galaxy_aggregate_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `UniverseIdentity`, `GalacticDensityModel`, budget, LOD level.
- Produces: `generate(identity, density_model, budget: int, level: StringName) -> Array[GalaxyAggregatePoint]`.
- Aggregate point exposes position, color weight and scale only; it has no system ID.

- [ ] **Step 1: Write failing aggregate tests**

```gdscript
var points = generator.generate(identity, density, 1000, &"cluster")
assert_true(points.size() <= 1000, "budget is an upper bound")
assert_true(points.size() > 0, "valid galaxy produces aggregate points")
assert_equal(_signature(points), _signature(generator.generate(identity, density, 1000, &"cluster")), "aggregate is stable")
assert_true(not points[0].get_property_list().any(func(p): return p.name == "system_id"), "aggregate has no canonical ID")
```

Assert zero budget returns empty, identity/level changes signature and every point
is inside the halo.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_galaxy_aggregate_generator.gd'
```

- [ ] **Step 3: Implement bounded rejection sampling**

Use a local RNG seeded through `SeedMixer.mix_text(identity.value,
"aggregate:%s:%d" % [level, budget])`. Attempt at most `budget * 20` samples in
the halo square. Accept a point when a second random value is at most
`density_at(position)`. Stop at budget. Derive scale/color weight from density;
never call `UniverseGenerator` or create system definitions.

- [ ] **Step 4: Run focused/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_galaxy_aggregate_generator.gd'
./tools/run_godot_tests.ps1
git add scripts/application/projections/galaxy_aggregate_point.gd scripts/application/projections/galaxy_aggregate_generator.gd tests/application/projections/test_galaxy_aggregate_generator.gd tests/test_runner.gd
git commit -m "feat: project aggregate galaxy points"
git push
```

### Task 4: Aggregate MultiMesh view

**Files:**
- Create: `scripts/adapters/godot_view/galaxy_overview_view.gd`
- Create: `tests/adapters/godot_view/test_galaxy_overview_view.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: prepared aggregate points and LOD level.
- Produces: `present(points: Array, level: StringName)`, `clear()`, `point_count()`, `level`.
- Does not expose picking or canonical IDs.

- [ ] **Step 1: Write failing view tests**

Assert one `MultiMeshInstance3D`, exact instance count/transforms, level replacement,
clear behavior and absence of system metadata.

- [ ] **Step 2: Run RED and implement**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_galaxy_overview_view.gd'
```

Use a low-poly shared sphere/quad mesh, `use_colors = true`, instance transforms
from aggregate positions and instance colors derived from color weight. Set a
manual `custom_aabb` covering the configured halo to avoid repeated AABB work.

- [ ] **Step 3: Run GREEN/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_galaxy_overview_view.gd'
./tools/run_godot_tests.ps1
git add scripts/adapters/godot_view/galaxy_overview_view.gd tests/adapters/godot_view/test_galaxy_overview_view.gd tests/test_runner.gd
git commit -m "feat: render aggregate galaxy levels"
git push
```

### Task 5: LOD coordinator and demo integration

**Files:**
- Create: `scripts/adapters/godot_view/galaxy_lod_controller.gd`
- Create: `tests/adapters/godot_view/test_galaxy_lod_controller.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: policy, detail stream/view, overview view, aggregate generator, identity, density model, task executor, effective profile.
- Produces: `update_zoom(zoom)`, `update_view(zoom, viewport_size)`, `set_profile(profile)`, `current_level`, `shutdown()`.

- [ ] **Step 1: Write failing coordinator tests with spies/manual executor**

Assert:

- detail enables stream and hides overview;
- cluster/overview disable stream and never request sectors;
- aggregate generation uses the profile budget and runs through executor;
- aggregate submission rejected by the shared capacity is retried without duplicating work;
- old aggregate result cannot replace a newer level;
- previous view remains until the new aggregate is ready;
- profile change regenerates only presentation points;
- max zoom creates zero sector requests.

- [ ] **Step 2: Run RED and implement orchestration**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_galaxy_lod_controller.gd'
```

Use an aggregate request generation counter independent from universe identity.
On detail, call `stream.set_detail_enabled(true)` and `stream.update_view`. On
cluster/overview, disable detail immediately, submit at most one aggregate job and
publish it only if generation and requested level still match. Borrow the single
demo-owned executor from Plan 2 with low priority; never call its `shutdown()`.

- [ ] **Step 3: Replace demo detail view and route camera updates**

Instantiate `MultiMeshStarFieldView`, `GalaxyOverviewView` and
`GalaxyLodController`. Connect camera zoom and viewport changes to the LOD
controller. Flush detail batches once per main-thread process after sector results
are applied. Preserve Sol startup at initial detail zoom.

- [ ] **Step 4: Run focused/full/catalog/smoke tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_galaxy_lod_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

Expected: PASS, catalog valid, smoke exit `0`.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/adapters/godot_view/galaxy_lod_controller.gd scripts/demo/infinite_star_map_demo.gd tests/adapters/godot_view/test_galaxy_lod_controller.gd tests/demo/test_infinite_star_map_demo.gd tests/test_runner.gd
git commit -m "feat: switch galactic rendering by zoom"
git push
```

### Task 6: Click detection and detailed picking integration

**Files:**
- Modify: `scripts/adapters/godot_view/map_camera_controller.gd`
- Modify: `scripts/adapters/godot_view/multimesh_star_field_view.gd`
- Modify: `scripts/adapters/godot_view/galaxy_lod_controller.gd`
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Modify: `tests/adapters/godot_view/test_multimesh_star_field_view.gd`
- Modify: `tests/adapters/godot_view/test_galaxy_lod_controller.gd`

**Interfaces:**
- Camera emits `map_clicked(screen_position: Vector2)` only when left release did not activate drag.
- Camera produces `screen_to_render_plane(screen_position, viewport_size) -> Vector2`.
- LOD controller emits `system_selected(system_definition)` only in detail.

- [ ] **Step 1: Add failing click-vs-drag tests**

Test a press/release below threshold emits once, an activated drag emits never,
and screen conversion uses orthographic size, aspect and camera local position.

```gdscript
var center = camera.screen_to_render_plane(Vector2(500, 250), Vector2(1000, 500))
assert_equal(center, camera.logical_position.local, "screen center maps to camera local")
```

- [ ] **Step 2: Implement camera signal and conversion**

Capture `was_drag_active` before `end_drag()`. Emit the release event position only
when false. Conversion formula:

```gdscript
var from_center := screen_position - viewport_size * 0.5
return logical_position.local + from_center * (size / viewport_size.y)
```

Reject invalid viewport by returning `logical_position.local`.

- [ ] **Step 3: Rebuild picking index during detail flush**

Feed each real system ID and render position to `SystemPickingIndex`. Convert
`settings.performance_selection_tolerance_pixels` to world tolerance with
`camera.size / viewport_height`. Ignore clicks unless current LOD is detail.

- [ ] **Step 4: Run tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_multimesh_star_field_view.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_galaxy_lod_controller.gd'
./tools/run_godot_tests.ps1
git add scripts/adapters/godot_view/map_camera_controller.gd scripts/adapters/godot_view/multimesh_star_field_view.gd scripts/adapters/godot_view/galaxy_lod_controller.gd tests/adapters/godot_view/test_map_camera_controller.gd tests/adapters/godot_view/test_multimesh_star_field_view.gd tests/adapters/godot_view/test_galaxy_lod_controller.gd
git commit -m "feat: select systems from detailed star batches"
git push
```

## Plan 3 Completion Gate

At maximum zoom assert `current_level == overview`, sector pending/running counts are
zero and no system-selection signal is emitted. At initial zoom assert Sol is a
real MultiMesh instance and is selectable. Run full tests, catalog validation,
30-second smoke and a GUI check across detail, cluster and overview transitions.
