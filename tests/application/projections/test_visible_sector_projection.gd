extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const ProjectionScript = preload("res://scripts/application/projections/visible_sector_projection.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var projection = ProjectionScript.new()
	var center = Coordinate.new(4, -2)
	assert_equal(
		projection.load_radii(300.0, 16.0 / 9.0),
		Vector2i(14, 14),
		"render scale grows with zoom and respects the configured aspect cap"
	)
	assert_equal(
		projection.load_radii(300.0, 9.0 / 16.0),
		Vector2i(8, 14),
		"portrait scale follows visible width"
	)
	assert_equal(
		projection.load_radii(300.0, 32.0 / 9.0),
		Vector2i(14, 14),
		"ultrawide scale respects the configured aspect cap"
	)
	assert_equal(
		projection.load_radii(300.0, 1920.0),
		Vector2i(14, 14),
		"degenerate wide viewport clamps before scaling"
	)
	assert_equal(
		projection.load_radii(300.0, 1.0 / 1920.0),
		Vector2i(4, 14),
		"degenerate tall viewport retains scaled horizontal coverage"
	)
	assert_equal(
		projection.load_radii(500.0, 1.0),
		Vector2i(35, 35),
		"midpoint zoom uses the midpoint render scale"
	)
	assert_equal(
		projection.load_radii(30.0, 1.0),
		Vector2i(1, 1),
		"near zoom loads only the current and neighboring sectors"
	)
	assert_equal(
		projection.load_radii(1000.0, 1.0),
		Vector2i(125, 125),
		"maximum zoom reaches the configured maximum render scale"
	)
	var distance_three = center.offset(3, 3)
	var far = [center.offset(4, 0), center.offset(0, -4), distance_three]
	var unload = projection.unload_coordinates(center, far, Vector2i(3, 3))
	assert_equal(unload.size(), 2, "only distance above three unloads")
	assert_true(not unload.has(distance_three), "distance three remains active")

	var rectangular_unload = projection.unload_coordinates(
		center,
		[center.offset(8, 0), center.offset(0, 6), center.offset(9, 0)],
		Vector2i(9, 6)
	)
	assert_equal(rectangular_unload.size(), 0, "coordinates inside rectangular radius remain")
	var beyond_rectangular = center.offset(0, 7)
	assert_equal(
		projection.unload_coordinates(center, [beyond_rectangular], Vector2i(9, 6)),
		[beyond_rectangular],
		"coordinate beyond either rectangular axis unloads"
	)

	var custom = Settings.duplicate(true)
	custom.universe_sector_size = 100.0
	custom.stream_render_scale = 1.0
	custom.stream_load_margin = 2
	custom.stream_unload_margin = 4
	custom.stream_min_aspect_ratio = 0.5
	custom.stream_max_aspect_ratio = 2.0
	var configured_projection = ProjectionScript.new(custom)
	var configured_load = configured_projection.load_radii(100.0, 10.0)
	assert_equal(configured_load, Vector2i(3, 3), "coverage uses injected settings")
	assert_equal(
		configured_projection.unload_radii(configured_load),
		Vector2i(7, 7),
		"hysteresis uses injected settings"
	)
