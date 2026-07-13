extends "res://tests/test_case.gd"

const Demo = preload("res://scenes/demo/infinite_star_map_demo.tscn")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	_test_composes_infinite_map_and_progressively_loads_initial_sectors()
	_test_hud_reports_map_stats_and_zoom()
	_test_maximum_zoom_refreshes_stream_coverage_and_hud()
	_test_viewport_resize_signal_refreshes_portrait_and_ultrawide_coverage()


func _test_composes_infinite_map_and_progressively_loads_initial_sectors() -> void:
	var demo = Demo.instantiate()
	var camera = demo.get_node_or_null("MapCamera")
	var stream = demo.get_node_or_null("SectorStreamController")
	var sector_root = demo.get_node_or_null("SectorRoot")
	assert_true(camera != null, "map camera exists")
	assert_true(stream != null, "stream controller exists")
	assert_true(sector_root != null, "sector root exists")
	assert_true(demo.get_node_or_null("DebugHud/Stats") != null, "debug HUD exists")
	assert_equal(
		demo.get_node("WorldEnvironment").environment.background_color,
		Settings.map_background_color,
		"map environment uses central settings"
	)
	assert_equal(sector_root.active_sector_count(), 0, "initial load starts progressively")
	stream.process_pending(1)
	assert_equal(sector_root.active_sector_count(), 1, "one pending sector loads")
	stream.process_pending(100)
	assert_equal(sector_root.active_sector_count(), 25, "initial sectors load")
	demo.free()


func _test_hud_reports_map_stats_and_zoom() -> void:
	var demo = Demo.instantiate()
	var camera = demo.get_node("MapCamera")
	var stats = demo.get_node("DebugHud/Stats")
	assert_true(stats.text.contains("Seed: 0x5A4F4449414B4F53"), "HUD shows fixed seed")
	assert_true(stats.text.contains("Sector: 0:0"), "HUD shows center sector")
	assert_true(stats.text.contains("Active: 0"), "HUD shows active sectors")
	assert_true(stats.text.contains("Stars: 0"), "HUD shows visible stars")
	assert_true(stats.text.contains("Zoom: 50.0"), "HUD shows initial zoom")
	camera.apply_zoom_steps(1)
	assert_true(stats.text.contains("Zoom: 44.0"), "HUD refreshes after zoom")
	demo.free()


func _test_maximum_zoom_refreshes_stream_coverage_and_hud() -> void:
	var demo = Demo.instantiate()
	Engine.get_main_loop().root.add_child(demo)
	var camera = demo.get_node("MapCamera")
	var stream = demo.get_node("SectorStreamController")
	camera.apply_zoom_steps(-200)
	assert_equal(camera.size, 300.0, "demo reaches approved maximum zoom")
	assert_equal(
		stream.load_radii,
		Vector2i(8, 5),
		"demo forwards maximum 16:9 coverage"
	)
	assert_true(
		demo.get_node("DebugHud/Stats").text.contains("Zoom: 300.0"),
		"HUD reports maximum zoom"
	)
	demo.free()


func _test_viewport_resize_signal_refreshes_portrait_and_ultrawide_coverage() -> void:
	var demo = Demo.instantiate()
	demo._ready()
	var camera = demo.get_node("MapCamera")
	var stream = demo.get_node("SectorStreamController")
	camera.apply_zoom_steps(-200)
	assert_true(
		Engine.get_main_loop().root.size_changed.is_connected(
			demo._refresh_stream_coverage
		),
		"demo connects viewport resize signal to stream refresh"
	)
	demo._refresh_stream_coverage(Vector2(900.0, 1600.0))
	assert_equal(
		stream.load_radii,
		Vector2i(4, 5),
		"portrait resize provides portrait stream coverage"
	)
	demo._refresh_stream_coverage(Vector2(3200.0, 900.0))
	assert_equal(
		stream.load_radii,
		Vector2i(15, 5),
		"ultrawide resize refreshes stream coverage"
	)
	demo.free()
