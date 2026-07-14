# Interactive Stellar Minimap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an interactive 2D minimap that queries deterministic stellar data beyond the 3D preload, switches between exact, cluster, and density LODs, and can recenter the main camera.

**Architecture:** Pure application services handle projection, LOD, density queries, and LRU caching without creating Godot 3D objects. A budgeted `MinimapController` owns query generations and navigation state, while a reusable `StellarMinimap` `Control` draws immutable snapshots and emits input intents; the demo composes both with the existing repository, universe generator, camera, and stream.

**Tech Stack:** Godot 4.7 Compatibility renderer, typed GDScript, CanvasItem `_draw`, existing SQLite catalog adapter, existing deterministic universe generator, PowerShell tests on Windows.

## Global Constraints

- Work only in the existing Windows worktree and never use WSL.
- Preserve unrelated Inspector edits, scene UID serialization, `.gd.uid` files, and the temporary SQLite DLL.
- Keep every source file under 1000 lines and keep configuration declarations in `GameSettings`.
- The minimap must never create meshes, `Node3D`, `SubViewport`, or share the main stream pending queue.
- Exact mode is limited to 256 sectors, cluster mode through 4096 sectors, and density mode above 4096.
- Exact work uses 8 sectors per frame; density/cluster work uses 128 cells per frame.
- Compact size is `320 × 220`; expanded ratio is `0.7`; `M` toggles the state.
- No minimap state is persisted and minimap settings do not version the universe identity.
- Follow TDD, verify RED then GREEN, and commit/push each task.

---

### Task 1: Minimap Settings, Projection, and LOD

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Create: `scripts/application/minimap/minimap_projection.gd`
- Create: `scripts/application/minimap/minimap_lod_policy.gd`
- Modify: `tests/config/test_game_settings.gd`
- Create: `tests/application/minimap/test_minimap_projection.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `MinimapProjection.new(center, view_height, aspect)`, `bounds()`, `world_to_pixel(...)`, `pixel_to_world(...)`, `zoom_at(...)`; `MinimapLodPolicy.select(sector_count) -> StringName`.

- [ ] **Step 1: Write failing configuration and identity tests**

Assert all exact values from the spec, invalid ordering/ranges, and that changing
every minimap field leaves `UniverseIdentity.value` unchanged.

- [ ] **Step 2: Write failing projection and LOD tests**

```gdscript
var projection = Projection.new(Vector2(100.0, -50.0), 400.0, 2.0)
var pixel := projection.world_to_pixel(Vector2(100.0, -50.0), Rect2(10, 20, 800, 400))
assert_equal(pixel, Vector2(410.0, 220.0), "center maps to drawing center")
assert_true(
	projection.pixel_to_world(pixel, Rect2(10, 20, 800, 400)).is_equal_approx(Vector2(100, -50)),
	"coordinate transforms are inverse"
)
var anchored := projection.zoom_at(1, Vector2(610, 220), Rect2(10, 20, 800, 400), 0.8, 40, 120000)
assert_true(
	anchored.pixel_to_world(Vector2(610, 220), Rect2(10, 20, 800, 400)).is_equal_approx(
		projection.pixel_to_world(Vector2(610, 220), Rect2(10, 20, 800, 400))
	),
	"zoom stays anchored to cursor"
)
assert_equal(policy.select(256), &"exact", "256 sectors use exact LOD")
assert_equal(policy.select(257), &"cluster", "257 sectors use cluster LOD")
assert_equal(policy.select(4096), &"cluster", "4096 sectors remain clustered")
assert_equal(policy.select(4097), &"density", "4097 sectors use density LOD")
```

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/minimap/test_minimap_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: missing settings/scripts.

- [ ] **Step 4: Implement settings, projection, and LOD policy**

Add the 14 approved minimap fields and finite/range/order validation. Implement
projection with immutable-returning `zoom_at` and bounds based on height/aspect:

```gdscript
func bounds() -> Rect2:
	var size := Vector2(view_height * aspect_ratio, view_height)
	return Rect2(center_global - size * 0.5, size)

func world_to_pixel(world: Vector2, drawing_rect: Rect2) -> Vector2:
	var normalized := (world - bounds().position) / bounds().size
	return drawing_rect.position + normalized * drawing_rect.size
```

LOD policy returns exact/cluster/density using configured thresholds.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 3 commands. Expected: all pass.

- [ ] **Step 6: Commit and push**

```powershell
git commit -m "feat: add minimap projection and lod settings"
git push origin codex/star-map-engine
```

---

### Task 2: Data-only Query Service and LRU Cache

**Files:**
- Create: `scripts/application/minimap/minimap_sector_cache.gd`
- Create: `scripts/application/minimap/minimap_query_service.gd`
- Create: `tests/application/minimap/test_minimap_query_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `LoadGalaxySector.generate_sector`, `ScientificCatalogRepository.systems_in_bounds`, `GalacticDensityModel.density_at`, universe identity.
- Produces: `exact_sector(coordinate)`, `catalog_points(bounds)`, `sample_cell(bounds, resolution, index, mode)`, cache `get/put/size/clear`.

- [ ] **Step 1: Write failing cache/query tests**

Use a counting fake sector source and repository. Prove a second lookup is a
cache hit, the third insert into a two-entry cache evicts the least-recently-used
entry, exact points preserve source/type/global position, catalog bounds are
queried once, and density/cluster samples are deterministic.

- [ ] **Step 2: Run the query suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/minimap/test_minimap_query_service.gd'
```

- [ ] **Step 3: Implement cache and query service**

Cache keys include identity, generator version, and coordinate. `exact_sector`
returns cached `UniverseSector`; `exact_points` converts each system with:

```gdscript
var global := Vector2(system.sector.x, system.sector.y) * sector_size + system.local_position
```

`sample_cell` returns rect, center, density, and an estimated count for cluster
mode; density mode omits count. Neither path enumerates procedural systems.

- [ ] **Step 4: Run the query suite and verify GREEN**

- [ ] **Step 5: Commit and push**

```powershell
git commit -m "feat: add minimap data query and cache"
git push origin codex/star-map-engine
```

---

### Task 3: Budgeted Minimap Controller

**Files:**
- Create: `scripts/adapters/godot_view/minimap_controller.gd`
- Create: `tests/adapters/godot_view/test_minimap_controller.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: Task 1 projection/LOD, Task 2 query service, `SectorRingIterator`.
- Produces: `configure(service, center, camera_zoom, aspect, preload_height)`, `set_main_camera_state(...)`, `pan_pixels(...)`, `zoom_steps_at(...)`, `center_on_main_camera()`, `process_pending(...)`, `snapshot_changed`, `navigation_requested`.

- [ ] **Step 1: Write failing controller tests**

Prove initial height fits both camera scale and preload, exact mode processes at
most eight sectors per batch, cluster/density process at most 128 cells, a stale
generation id publishes nothing, panning disables follow, centering restores
follow, zoom stays cursor-anchored, and navigation re-enables follow.

- [ ] **Step 2: Run controller suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_minimap_controller.gd'
```

- [ ] **Step 3: Implement generation state and budget processing**

The controller stores `generation_id`, one active ring iterator or cell index,
exact points, catalog points, cells, loading state, visible/preload rectangles,
and error count. Every bounds refresh increments the id and replaces pending
work. `process_pending(limit, requested_generation)` returns without changes for
a stale id and publishes immutable duplicated arrays.

- [ ] **Step 4: Implement navigation state**

Pan converts pixels using `view_height / panel_height`; zoom delegates to
`MinimapProjection.zoom_at`; both schedule a 100 ms debounce. Test-only direct
`refresh_now` and `process_pending` remain valid production APIs for deterministic
manual processing.

- [ ] **Step 5: Run controller suite and verify GREEN**

- [ ] **Step 6: Commit and push**

```powershell
git commit -m "feat: add budgeted minimap controller"
git push origin codex/star-map-engine
```

---

### Task 4: Interactive StellarMinimap Control

**Files:**
- Create: `scripts/adapters/godot_view/stellar_minimap.gd`
- Create: `tests/adapters/godot_view/test_stellar_minimap.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: controller snapshots.
- Produces: `pan_requested(delta, panel_size)`, `zoom_requested(steps, cursor, drawing_rect)`, `navigation_requested(global)`, `center_requested`, compact/expanded state, and drawing via `_draw`.

- [ ] **Step 1: Write failing view tests**

Assert compact size/anchors, `M` toggling, metric labels, snapshot coordinate
mapping, wheel signal, drag signal, double-click global target, center button,
mouse filtering, and that systems/cells/visible/preload overlays trigger redraw.

- [ ] **Step 2: Run view suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_stellar_minimap.gd'
```

- [ ] **Step 3: Implement component and input intents**

Create a `PanelContainer` programmatically, with header, LOD/loading labels,
center button, and an inner custom drawing control. Handle wheel/drag/double
click in `_gui_input`, consume events, and use `VisualPalette.star_style` for
point colors. Draw scientific outlines white, cluster circles, density cells,
blue visible bounds, orange preload bounds, and center cross.

- [ ] **Step 4: Implement compact/expanded layout**

Compact uses bottom-right offsets for 320×220. Expanded uses anchors 0.15 to
0.85. Switching layout preserves snapshot and navigation state.

- [ ] **Step 5: Run view suite and verify GREEN**

- [ ] **Step 6: Commit and push**

```powershell
git commit -m "feat: add interactive stellar minimap view"
git push origin codex/star-map-engine
```

---

### Task 5: Demo Composition and Camera Navigation

**Files:**
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Consumes: all minimap components, existing runtime settings, catalog repository, sector source, camera, stream.
- Produces: `DebugHud/StellarMinimap`, `MinimapController`, live overlays, and double-click main-camera navigation.

- [ ] **Step 1: Write failing demo integration tests**

Assert both nodes exist, the query service shares the already-open repository
and sector source, minimap work does not change main stream pending/active
counts, camera movement updates follow center, preload/visible rectangles enter
the snapshot, and navigation to a negative global coordinate produces the
correct normalized `UniversePosition` and updates the stream center.

- [ ] **Step 2: Run demo suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

- [ ] **Step 3: Compose minimap after catalog validation**

Retain `sector_source` and procedural generator as demo members. Create query
service/controller, create the visual under `DebugHud`, connect intents, and
initialize height with:

```gdscript
maxf(
	map_camera.size * runtime_settings.minimap_initial_view_scale,
	float(2 * stream.load_radii.y + 1) * runtime_settings.universe_sector_size * 1.1
)
```

- [ ] **Step 4: Synchronize overlays and navigation**

Update controller state on camera position, camera zoom, stream stats, and
viewport resize. Convert navigation target using `UniversePosition.new` and
call `map_camera.set_logical_position`.

- [ ] **Step 5: Run demo and minimap focused suites GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_minimap_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_stellar_minimap.gd'
```

- [ ] **Step 6: Commit and push**

```powershell
git commit -m "feat: integrate stellar minimap with star map"
git push origin codex/star-map-engine
```

---

### Task 6: Full Verification

**Files:** verify only unless a failing check reveals a tested defect.

- [ ] **Step 1: Run all tests**

```powershell
./tools/run_godot_tests.ps1
```

Expected: `TESTS PASSED`, review checks passed, wrapper passed.

- [ ] **Step 2: Validate catalog and smoke boot**

```powershell
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

- [ ] **Step 3: Enforce source constraints**

```powershell
git diff --check
rg -n "SubViewport|ResourceSaver|ConfigFile" scripts/application/minimap scripts/adapters/godot_view/stellar_minimap.gd scripts/adapters/godot_view/minimap_controller.gd
$tooLong = Get-ChildItem scripts,tests -Recurse -Filter *.gd | Where-Object { (Get-Content $_.FullName).Count -gt 1000 }
if ($tooLong) { $tooLong.FullName; exit 1 }
```

Expected: no prohibited runtime types/persistence and no file over 1000 lines.

- [ ] **Step 4: Restore user Inspector edits and sync remote**

Verify the preserved `camera_max_zoom = 1000`, `stream_viewport_grid_size = 10`,
scene UIDs, generated UIDs, and DLL remain outside commits. Push and prove local
and remote SHAs match.
