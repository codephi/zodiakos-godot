extends "res://tests/test_case.gd"

const CameraController = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")


func run() -> void:
	_test_drag_threshold_and_floating_position()
	_test_zoom_clamps_and_signal()


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
	assert_equal(camera.MAXIMUM_SIZE, 300.0, "map can zoom out to the approved distance")

	camera.apply_zoom_steps(100)
	assert_equal(camera.size, camera.MINIMUM_SIZE, "zoom in clamps exactly to the minimum")
	camera.apply_zoom_steps(-200)
	assert_equal(camera.size, camera.MAXIMUM_SIZE, "zoom out clamps exactly to the maximum")
	assert_equal(changed_sizes, [camera.MINIMUM_SIZE, camera.MAXIMUM_SIZE], "each zoom command emits the clamped size")
	camera.free()
