extends "res://tests/test_case.gd"

const CameraController = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Settings = preload("res://config/game_settings.tres")
const UniversePositionType = preload("res://scripts/domain/universe/universe_position.gd")


func run() -> void:
	_test_set_logical_position_copies_normalizes_and_emits()
	_test_drag_threshold_and_floating_position()
	_test_zoom_clamps_and_signal()
	_test_zoom_anchors_to_current_cursor()
	_test_zoom_uses_each_scroll_events_current_cursor()
	_test_zoom_limits_and_invalid_viewport_do_not_move_camera()
	_test_camera_uses_injected_settings()


func _test_set_logical_position_copies_normalizes_and_emits() -> void:
	var camera = CameraController.new()
	var supplied = UniversePositionType.new(
		Coordinate.new(202, 0),
		Vector2.ZERO,
		Settings.universe_sector_size
	)
	supplied.local = Vector2(70.0, 0.0)
	var emitted: Array = []
	camera.logical_position_changed.connect(func(position): emitted.append(position))

	camera.set_logical_position(supplied)

	assert_equal(camera.logical_position.sector.key(), "203:0", "setter normalizes sector")
	assert_equal(camera.logical_position.local, Vector2(30.0, 0.0), "setter normalizes local position")
	assert_equal(camera.position.x, 30.0, "setter synchronizes the visual transform")
	assert_equal(emitted.size(), 1, "setter emits one logical position change")
	supplied.local = Vector2.ZERO
	assert_equal(
		camera.logical_position.local,
		Vector2(30.0, 0.0),
		"camera does not retain the supplied mutable position"
	)
	camera.free()


func _test_drag_threshold_and_floating_position() -> void:
	var camera = CameraController.new()
	var initial_height: float = camera.position.y
	var changed_positions: Array = []
	camera.logical_position_changed.connect(func(position): changed_positions.append(position))

	camera.begin_drag()
	camera.accumulate_drag_pixels(Vector2(2.0, 0.0), 1000.0)
	assert_equal(camera.logical_position.local, Vector2.ZERO, "motion below four accumulated pixels remains a click")
	camera.accumulate_drag_pixels(Vector2(2.0, 0.0), 1000.0)
	assert_equal(camera.logical_position.sector.key(), "-1:0", "exactly four accumulated pixels activates dragging")
	assert_equal(camera.logical_position.local, Vector2(39.8, 0.0), "activated dragging normalizes local coordinates")
	camera.accumulate_drag_pixels(Vector2(796.0, 800.0), 1000.0)
	camera.end_drag()

	assert_equal(camera.logical_position.sector.key(), "-1:-1", "drag normalizes the logical sector deterministically")
	assert_equal(camera.logical_position.local, Vector2.ZERO, "drag normalizes the logical local position deterministically")
	assert_equal(camera.position, Vector3(0.0, initial_height, 0.0), "drag syncs the floating visual position without changing height")
	assert_equal(changed_positions.size(), 2, "each applied drag emits one logical position change")

	camera.apply_drag_pixels(Vector2(-900.0, -900.0), 1000.0)
	assert_equal(camera.logical_position.sector.key(), "0:0", "reverse drag crosses sectors deterministically")
	assert_equal(camera.logical_position.local, Vector2(5.0, 5.0), "reverse drag preserves normalized local coordinates")
	assert_equal(camera.position, Vector3(5.0, initial_height, 5.0), "visual camera uses bounded local coordinates")
	camera.free()


func _test_zoom_clamps_and_signal() -> void:
	var camera = CameraController.new()
	var changed_sizes: Array[float] = []
	camera.zoom_changed.connect(func(new_size: float): changed_sizes.append(new_size))
	assert_equal(Settings.camera_max_zoom, 100.0, "map can zoom out to the approved distance")

	camera.apply_zoom_steps(100)
	var zoomed_in_size: float = camera.size
	assert_true(zoomed_in_size > 0.0, "finite zoom-in remains positive")
	assert_true(zoomed_in_size < 0.001, "large zoom-in approaches the zero minimum")
	camera.apply_zoom_steps(-200)
	assert_equal(camera.size, Settings.camera_max_zoom, "zoom out clamps exactly to the maximum")
	assert_equal(
		changed_sizes,
		[zoomed_in_size, Settings.camera_max_zoom],
		"each zoom command emits its size"
	)
	camera.free()


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
	camera.apply_zoom_steps(-100)
	assert_equal(camera.size, Settings.camera_max_zoom, "no-signal test reaches maximum zoom")
	positions.clear()
	sizes.clear()
	camera.apply_zoom_at(-1, Vector2(900.0, 250.0), Vector2(1000.0, 500.0))
	assert_equal(camera.logical_position.local, Vector2.ZERO, "clamped zoom does not move the camera")
	assert_equal(positions.size(), 0, "clamped zoom emits no position change")
	assert_equal(sizes.size(), 0, "clamped zoom emits no size change")
	camera.free()


func _test_camera_uses_injected_settings() -> void:
	var custom = Settings.duplicate(true)
	custom.camera_min_zoom = 30.0
	custom.camera_max_zoom = 100.0
	custom.camera_initial_zoom = 60.0
	custom.camera_zoom_factor = 0.5
	custom.camera_height = 25.0
	custom.camera_drag_threshold_pixels = 2.0
	custom.universe_sector_size = 10.0
	var camera = CameraController.new(custom)
	assert_equal(camera.size, 60.0, "initial zoom comes from injected settings")
	assert_equal(camera.position.y, 25.0, "camera height comes from injected settings")
	camera.apply_zoom_steps(1)
	assert_equal(camera.size, 30.0, "zoom factor and minimum come from injected settings")
	camera.begin_drag()
	camera.accumulate_drag_pixels(Vector2(2.0, 0.0), 60.0)
	assert_equal(camera.logical_position.sector.key(), "-1:0", "drag uses configured threshold")
	assert_equal(camera.logical_position.local, Vector2(9.0, 0.0), "camera position uses configured sector size")
	camera.free()
