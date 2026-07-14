extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const ProjectionScript = preload("res://scripts/application/projections/visible_sector_projection.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var projection = ProjectionScript.new()
	var center = Coordinate.new(4, -2)
	assert_equal(
		projection.load_radii(300.0, 16.0 / 9.0),
		Vector2i(20, 12),
		"three viewport widths and heights cover the 16:9 stream area"
	)
	assert_equal(
		projection.load_radii(300.0, 9.0 / 16.0),
		Vector2i(7, 12),
		"portrait coverage preserves the three by three viewport grid"
	)
	assert_equal(
		projection.load_radii(300.0, 32.0 / 9.0),
		Vector2i(40, 12),
		"ultrawide coverage preserves the supported viewport aspect"
	)
	assert_equal(
		projection.load_radii(300.0, 1920.0),
		Vector2i(45, 12),
		"degenerate wide viewport clamps before scaling"
	)
	assert_equal(
		projection.load_radii(300.0, 1.0 / 1920.0),
		Vector2i(3, 12),
		"degenerate tall viewport retains scaled horizontal coverage"
	)
	assert_equal(
		projection.load_radii(500.0, 1.0),
		Vector2i(19, 19),
		"viewport grid multiplier stays fixed outside production zoom"
	)
	assert_equal(
		projection.load_radii(30.0, 1.0),
		Vector2i(2, 2),
		"near zoom still preloads the eight neighboring viewports"
	)
	assert_equal(
		projection.load_radii(1000.0, 1.0),
		Vector2i(38, 38),
		"fixed viewport grid does not amplify with zoom progress"
	)
	assert_equal(
		projection.visible_radii(300.0, 1.0),
		Vector2i(4, 4),
		"visible coverage does not use render amplification"
	)
	assert_equal(
		projection.visible_radii(300.0, 9.0 / 16.0),
		Vector2i(3, 4),
		"visible coverage preserves safe rectangular aspect"
	)
	assert_equal(
		projection.visible_radii(100.0, 16.0 / 9.0),
		Vector2i(3, 2),
		"production maximum zoom keeps the visible center compact"
	)
	assert_equal(
		projection.load_radii(100.0, 16.0 / 9.0),
		Vector2i(7, 4),
		"production maximum zoom loads the exact surrounding viewport grid"
	)
	var visible_at_max: Vector2i = projection.visible_radii(100.0, 16.0 / 9.0)
	var load_at_max: Vector2i = projection.load_radii(100.0, 16.0 / 9.0)
	assert_true(
		load_at_max.x >= visible_at_max.x and load_at_max.y >= visible_at_max.y,
		"expanded coverage contains visible coverage"
	)
	var fixed = Settings.duplicate(true)
	fixed.stream_use_fixed_preload_zoom = true
	fixed.stream_fixed_preload_zoom = 1000.0
	fixed.stream_viewport_grid_size = 3
	var fixed_projection = ProjectionScript.new(fixed)
	assert_equal(
		fixed_projection.effective_preload_zoom(30.0),
		1000.0,
		"fixed preload zoom is a floor"
	)
	assert_equal(
		fixed_projection.visible_radii(30.0, 16.0 / 9.0),
		Vector2i(1, 1),
		"visible coverage continues to use camera zoom"
	)
	assert_equal(
		fixed_projection.load_radii(30.0, 16.0 / 9.0),
		Vector2i(67, 38),
		"preload coverage uses fixed zoom"
	)
	assert_equal(
		fixed_projection.effective_preload_zoom(1200.0),
		1200.0,
		"camera zoom above the fixed floor wins"
	)
	fixed.stream_use_fixed_preload_zoom = false
	assert_equal(
		fixed_projection.effective_preload_zoom(30.0),
		30.0,
		"disabled fixed preload follows camera zoom"
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
	custom.stream_viewport_grid_size = 1
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
