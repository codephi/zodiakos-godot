# Extended Star Map Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase the star map zoom-out limit to `300.0` while dynamically streaming enough deterministic sectors to fill the visible viewport.

**Architecture:** Keep camera limits in `MapCameraController`, calculate rectangular sector coverage in the pure `VisibleSectorProjection`, and let `SectorStreamController` reconcile that coverage without regenerating active sectors. The demo forwards zoom and viewport-size changes to the stream controller; generation and rendering remain unchanged.

**Tech Stack:** Godot 4.7, typed GDScript, Compatibility renderer, native Windows PowerShell test wrapper.

## Global Constraints

- Develop and validate on native Windows with PowerShell; do not use WSL.
- Keep handwritten files below 1,000 lines.
- Preserve deterministic generation and the event-driven hexagonal boundaries.
- Use TDD: observe each new assertion fail before changing production code.
- Run tests with `./tools/run_godot_tests.ps1` and finish with a headless main-scene smoke test.
- Commit and push after each completed task.

---

### Task 1: Extend the camera zoom limit

**Files:**
- Modify: `scripts/adapters/godot_view/map_camera_controller.gd:9-10`
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd:38-49`

**Interfaces:**
- Consumes: `MapCameraController.apply_zoom_steps(steps: int) -> void`
- Produces: `MapCameraController.MAXIMUM_SIZE == 300.0`

- [ ] **Step 1: Write the failing test**

Add an explicit expected-value assertion before the existing clamp exercise:

```gdscript
assert_equal(camera.MAXIMUM_SIZE, 300.0, "map can zoom out to the approved distance")
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
```

Expected: FAIL because `MAXIMUM_SIZE` is `90.0`, not `300.0`.

- [ ] **Step 3: Implement the minimal limit change**

Change only the maximum:

```gdscript
const MINIMUM_SIZE := 20.0
const MAXIMUM_SIZE := 300.0
```

- [ ] **Step 4: Verify GREEN**

Run the focused command again. Expected: `TESTS PASSED` and `GODOT TEST WRAPPER PASSED`.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/adapters/godot_view/map_camera_controller.gd tests/adapters/godot_view/test_map_camera_controller.gd
git commit -m "feat: extend star map zoom distance"
git push
```

---

### Task 2: Adapt streamed sector coverage to zoom and viewport

**Files:**
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Consumes: `UniverseScale.SECTOR_SIZE`, camera `size`, viewport `size`, existing active and queued sector keys.
- Produces: `VisibleSectorProjection.load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i`.
- Produces: `SectorStreamController.update_view(orthographic_size: float, viewport_size: Vector2) -> void`.
- Preserves: progressive loading, active-sector reuse, deterministic rematerialization, and `stats_changed` deduplication.

- [ ] **Step 1: Add failing pure-projection tests**

Extend the projection suite with:

```gdscript
assert_equal(
    projection.load_radii(300.0, 16.0 / 9.0),
    Vector2i(8, 5),
    "maximum zoom covers 16:9 viewport plus one sector margin"
)
var maximum_order = projection.load_order(center, {}, {}, Vector2i(8, 5))
assert_equal(maximum_order.size(), 187, "rectangular maximum coverage contains 17 by 11 sectors")
```

Update existing calls to pass `Vector2i(2, 2)` where the test intentionally verifies the original 25-sector ordering.

- [ ] **Step 2: Run projection suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
```

Expected: parse/runtime failure because `load_radii` and the fourth `load_order` argument do not exist.

- [ ] **Step 3: Implement rectangular coverage in the pure projection**

Use the shared sector scale and explicit margins:

```gdscript
const Scale = preload("res://scripts/domain/universe/universe_scale.gd")
const LOAD_MARGIN := 1
const UNLOAD_MARGIN := 1

func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
    var half_height := maxf(orthographic_size, 0.0) * 0.5
    var half_width := half_height * maxf(aspect_ratio, 0.0)
    return Vector2i(
        ceili(half_width / Scale.SECTOR_SIZE) + LOAD_MARGIN,
        ceili(half_height / Scale.SECTOR_SIZE) + LOAD_MARGIN
    )

func unload_radii(load: Vector2i) -> Vector2i:
    return load + Vector2i(UNLOAD_MARGIN, UNLOAD_MARGIN)
```

Change `load_order` to iterate `-radii.y..radii.y` and `-radii.x..radii.x`. Change `unload_coordinates` to remove a coordinate when its absolute X or Y delta exceeds the corresponding unload radius. Preserve distance-first then Y/X ordering.

- [ ] **Step 4: Verify projection GREEN**

Run the focused projection suite. Expected: wrapper and suite pass.

- [ ] **Step 5: Add failing streaming tests**

Add a test using `CountingGenerator`:

```gdscript
controller.configure(generator, view, origin)
controller.update_view(300.0, Vector2(1920.0, 1080.0))
controller.process_pending(500)
assert_equal(view.active_sector_count(), 187, "maximum zoom fills rectangular visible coverage")
var calls_at_maximum: Dictionary = generator.calls_by_sector.duplicate()
controller.update_view(300.0, Vector2(1920.0, 1080.0))
controller.process_pending(500)
assert_equal(generator.calls_by_sector, calls_at_maximum, "unchanged view does not regenerate active sectors")
controller.update_view(50.0, Vector2(1920.0, 1080.0))
controller.process_pending(500)
assert_true(view.active_sector_count() <= 63, "zooming in unloads sectors outside hysteresis")
```

- [ ] **Step 6: Run streaming suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: failure because `update_view` does not exist.

- [ ] **Step 7: Implement stream reconciliation**

Store current rectangular radii and add:

```gdscript
var load_radii := Vector2i(2, 2)
var unload_radii := Vector2i(3, 3)

func update_view(orthographic_size: float, viewport_size: Vector2) -> void:
    if viewport_size.y <= 0.0:
        return
    var next_load := projection.load_radii(orthographic_size, viewport_size.x / viewport_size.y)
    if next_load == load_radii:
        return
    load_radii = next_load
    unload_radii = projection.unload_radii(load_radii)
    update_center(center)
```

Pass `load_radii` and `unload_radii` into the projection calls in `update_center`. Keep queue clearing, active-key filtering, batch size, and statistics behavior unchanged.

- [ ] **Step 8: Verify streaming GREEN**

Run the focused streaming suite. Expected: all assertions pass, including reuse and hysteresis.

- [ ] **Step 9: Wire zoom and viewport changes in the demo**

In `_ready`, connect `get_viewport().size_changed` and refresh coverage. Extend `_on_zoom_changed` to refresh coverage before updating HUD:

```gdscript
func _ready() -> void:
    get_viewport().size_changed.connect(_refresh_stream_coverage)
    _refresh_stream_coverage()

func _refresh_stream_coverage() -> void:
    stream.update_view(map_camera.size, get_viewport().get_visible_rect().size)

func _on_zoom_changed(_new_size: float) -> void:
    _refresh_stream_coverage()
    _update_stats(
        sector_view.active_sector_count(),
        sector_view.star_count(),
        map_camera.logical_position.sector.key()
    )
```

Add a dedicated integration test that places the demo in the running test tree so `_ready` executes, then drives the real camera signal:

```gdscript
var demo = Demo.instantiate()
Engine.get_main_loop().root.add_child(demo)
var camera = demo.get_node("MapCamera")
var stream = demo.get_node("SectorStreamController")
camera.apply_zoom_steps(-200)
assert_equal(camera.size, 300.0, "demo reaches approved maximum zoom")
assert_equal(stream.load_radii, Vector2i(8, 5), "demo forwards maximum 16:9 coverage")
assert_true(demo.get_node("DebugHud/Stats").text.contains("Zoom: 300.0"), "HUD reports maximum zoom")
demo.free()
```

- [ ] **Step 10: Run the full verification**

```powershell
./tools/run_godot_tests.ps1
& 'C:\Users\phili\AppData\Local\Programs\Godot\4.7\godot_console.exe' --headless --path . --quit-after 5
git diff --check
git status -sb
```

Expected: tests and wrapper pass, smoke exits `0` without stderr, diff check is empty, and only Task 2 files are modified.

- [ ] **Step 11: Validate in the embedded preview**

Run the main scene, select **Entrada**, scroll outward until HUD reports `Zoom: 300.0`, and confirm stars continue to populate the visible area. Scroll further and confirm the HUD remains at `300.0`.

- [ ] **Step 12: Commit and push**

```powershell
git add scripts/application/projections/visible_sector_projection.gd scripts/adapters/godot_view/sector_stream_controller.gd scripts/demo/infinite_star_map_demo.gd tests/application/projections/test_visible_sector_projection.gd tests/adapters/godot_view/test_sector_streaming.gd tests/demo/test_infinite_star_map_demo.gd
git commit -m "feat: stream sectors for extended map zoom"
git push
```
