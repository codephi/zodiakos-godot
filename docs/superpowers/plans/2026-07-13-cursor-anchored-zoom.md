# Cursor-Anchored Map Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every mouse-wheel zoom step preserve the logical star-map point under the current cursor.

**Architecture:** Keep input, orthographic projection math, floating logical position, and signals inside `MapCameraController`. Add a deterministic `apply_zoom_at` method that accepts explicit cursor and viewport values, while retaining `apply_zoom_steps` as centered zoom for programmatic callers.

**Tech Stack:** Godot 4.7, GDScript, native Windows PowerShell, existing custom Godot test runner.

## Global Constraints

- Each scroll event uses the current cursor position.
- Mouse movement without scroll does not move or zoom the camera.
- Zoom-in and zoom-out preserve the point under the cursor.
- Reaching `MINIMUM_SIZE` or `MAXIMUM_SIZE` prevents further camera movement and signals in that direction.
- Existing drag controls, zoom factor, zoom limits, sector streaming, and HUD remain compatible.
- Handwritten files remain below 1,000 lines.
- Only the feature files are staged; the unrelated local `project.godot` change remains untouched.

---

### Task 1: Anchor orthographic zoom to the current cursor

**Files:**
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Modify: `scripts/adapters/godot_view/map_camera_controller.gd`

**Interfaces:**
- Consumes: `UniversePosition.moved(delta: Vector2)`, `MapCameraController.ZOOM_FACTOR`, `InputEventMouseButton.position`, and the current viewport size.
- Produces: `MapCameraController.apply_zoom_at(steps: int, cursor_position: Vector2, viewport_size: Vector2) -> void`.
- Preserves: `MapCameraController.apply_zoom_steps(steps: int) -> void` as centered programmatic zoom.

- [ ] **Step 1: Write the failing cursor-anchor tests**

Extend `run()` and add focused tests equivalent to:

```gdscript
func _test_zoom_anchors_to_current_cursor() -> void:
	var camera = CameraController.new()
	var positions: Array = []
	camera.logical_position_changed.connect(func(position): positions.append(position))

	camera.apply_zoom_at(1, Vector2(750.0, 250.0), Vector2(1000.0, 500.0))
	assert_true(is_equal_approx(camera.size, 44.0), "zoom in keeps the existing factor")
	assert_true(camera.logical_position.local.is_equal_approx(Vector2(3.0, 0.0)), "zoom in moves toward the cursor")

	camera.apply_zoom_at(-1, Vector2(750.0, 250.0), Vector2(1000.0, 500.0))
	assert_true(camera.logical_position.local.is_equal_approx(Vector2.ZERO), "inverse zoom preserves the anchored logical point")
	assert_equal(positions.size(), 2, "each cursor compensation emits a logical position change")
	camera.free()


func _test_zoom_uses_each_scroll_events_current_cursor() -> void:
	var camera = CameraController.new()
	camera.apply_zoom_at(1, Vector2(750.0, 250.0), Vector2(1000.0, 500.0))
	camera.apply_zoom_at(1, Vector2(250.0, 250.0), Vector2(1000.0, 500.0))
	assert_true(camera.logical_position.local.is_equal_approx(Vector2(0.36, 0.0)), "moving the cursor redirects the next zoom step")
	camera.free()


func _test_zoom_limits_and_invalid_viewport_do_not_move_camera() -> void:
	var camera = CameraController.new()
	var positions: Array = []
	var sizes: Array[float] = []
	camera.logical_position_changed.connect(func(position): positions.append(position))
	camera.zoom_changed.connect(func(new_size: float): sizes.append(new_size))

	camera.apply_zoom_at(1, Vector2(750.0, 250.0), Vector2(1000.0, 0.0))
	assert_equal(camera.logical_position.local, Vector2.ZERO, "invalid viewport ignores cursor compensation")
	camera.apply_zoom_steps(100)
	positions.clear()
	sizes.clear()
	camera.apply_zoom_at(1, Vector2(900.0, 250.0), Vector2(1000.0, 500.0))
	assert_equal(camera.logical_position.local, Vector2.ZERO, "clamped zoom does not move the camera")
	assert_equal(positions.size(), 0, "clamped zoom emits no position change")
	assert_equal(sizes.size(), 0, "clamped zoom emits no size change")
	camera.free()
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
```

Expected: FAIL because `MapCameraController.apply_zoom_at` does not exist.

- [ ] **Step 3: Implement the minimal cursor-anchored zoom**

Update wheel handling to pass `event.position` and the visible viewport size. Implement the public API with this projection rule:

```gdscript
func apply_zoom_steps(steps: int) -> void:
	apply_zoom_at(steps, Vector2.ZERO, Vector2.ZERO)


func apply_zoom_at(steps: int, cursor_position: Vector2, viewport_size: Vector2) -> void:
	var previous_size := size
	var next_size := previous_size
	if steps > 0:
		next_size *= pow(ZOOM_FACTOR, steps)
	elif steps < 0:
		next_size /= pow(ZOOM_FACTOR, -steps)
	next_size = clampf(next_size, MINIMUM_SIZE, MAXIMUM_SIZE)
	if is_equal_approx(next_size, previous_size):
		return

	size = next_size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var cursor_from_center := cursor_position - viewport_size * 0.5
		var logical_delta := cursor_from_center * ((previous_size - next_size) / viewport_size.y)
		if not logical_delta.is_zero_approx():
			logical_position = logical_position.moved(logical_delta)
			sync_visual_position()
			logical_position_changed.emit(logical_position)
	zoom_changed.emit(size)
```

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
```

Expected: `TESTS PASSED` and `GODOT TEST WRAPPER PASSED`, with empty stderr.

- [ ] **Step 5: Run complete verification**

Run:

```powershell
./tools/run_godot_tests.ps1
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --editor --quit
git diff --check
```

Expected: all tests pass, the Godot smoke process exits `0` without stderr, and the feature diff has no whitespace errors.

- [ ] **Step 6: Commit and push only feature files**

```powershell
git add scripts/adapters/godot_view/map_camera_controller.gd tests/adapters/godot_view/test_map_camera_controller.gd
git commit -m "feat: anchor map zoom to cursor"
git push origin codex/star-map-engine
```
