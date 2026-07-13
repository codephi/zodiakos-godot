extends "res://tests/test_case.gd"

const Demo = preload("res://scenes/demo/infinite_star_map_demo.tscn")
const DemoScript = preload("res://scripts/demo/infinite_star_map_demo.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const RepositoryPort = preload(
	"res://scripts/application/ports/scientific_catalog_repository.gd"
)
const Settings = preload("res://config/game_settings.tres")

class InvalidCatalogRepository:
	extends RepositoryPort

	var open_calls := 0
	var close_calls := 0


	func open() -> bool:
		open_calls += 1
		return true


	func close() -> void:
		close_calls += 1


	func metadata():
		return Metadata.new(1, 2, 1)


	func systems_in_bounds(_bounds: Rect2) -> Array:
		return []


	func technical_validation_errors() -> Array[Dictionary]:
		return [{"code": &"SYNTHETIC_INVALID", "message": "Synthetic invalid catalog"}]


func run() -> void:
	_test_composes_infinite_map_and_progressively_loads_initial_sectors()
	_test_real_catalog_stays_open_and_materializes_sol_at_startup()
	_test_invalid_catalog_blocks_streaming_and_reports_one_explicit_error()
	_test_hud_reports_map_stats_and_zoom()
	_test_reference_zoom_refreshes_stream_coverage()
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


func _test_real_catalog_stays_open_and_materializes_sol_at_startup() -> void:
	var demo = Demo.instantiate()
	Engine.get_main_loop().root.add_child(demo)
	var camera = demo.get_node("MapCamera")
	var stream = demo.get_node("SectorStreamController")
	var sector_root = demo.get_node("SectorRoot")
	assert_equal(camera.logical_position.sector.key(), "203:0", "demo starts in Sol sector")
	assert_equal(camera.logical_position.local, Vector2(30.0, 0.0), "demo starts at Sol local position")
	assert_equal(stream.center.key(), "203:0", "stream is configured around Sol")
	assert_true(
		camera.logical_position_changed.is_connected(stream.update_center),
		"camera updates the stream after initial configuration"
	)
	assert_true(demo.catalog_repository != null, "demo retains its catalog repository")
	assert_true(demo.catalog_repository._database != null, "catalog remains open while demo lives")
	assert_true(demo.catalog_repository._database.read_only, "production catalog is read-only")
	stream.process_pending(1)
	assert_true(
		sector_root.sector_signature(camera.logical_position.sector).has("catalog:sol"),
		"startup sector materializes the cataloged Solar System"
	)
	var retained_repository = demo.catalog_repository
	demo._exit_tree()
	assert_true(retained_repository._database == null, "demo closes the catalog on tree exit")
	demo.free()


func _test_invalid_catalog_blocks_streaming_and_reports_one_explicit_error() -> void:
	var repository = InvalidCatalogRepository.new()
	var demo = DemoScript.new(repository)
	var stream = demo.get_node("SectorStreamController")
	var stats = demo.get_node("DebugHud/Stats")
	assert_equal(repository.open_calls, 1, "demo opens the injected repository")
	assert_equal(repository.close_calls, 1, "invalid repository is closed immediately")
	assert_true(stream.generator == null, "invalid catalog prevents stream configuration")
	assert_true(stream.center == null, "invalid catalog leaves the stream without a center")
	assert_true(stream.pending.is_empty(), "invalid catalog queues no sectors")
	assert_true(stats.text.begins_with("CATALOG_INVALID:"), "HUD error uses the stable prefix")
	assert_equal(stats.text.count("CATALOG_INVALID:"), 1, "HUD contains one catalog error")
	demo._ready()
	demo.get_node("MapCamera").apply_zoom_steps(1)
	assert_true(
		stats.text.begins_with("CATALOG_INVALID:"),
		"unconfigured lifecycle and zoom preserve the catalog error"
	)
	demo.free()


func _test_hud_reports_map_stats_and_zoom() -> void:
	var demo = Demo.instantiate()
	var camera = demo.get_node("MapCamera")
	var stats = demo.get_node("DebugHud/Stats")
	assert_true(stats.text.contains("Seed: 0x5A4F4449414B4F53"), "HUD shows fixed seed")
	assert_true(stats.text.contains("Sector: 203:0"), "HUD shows center sector")
	assert_true(stats.text.contains("Active: 0"), "HUD shows active sectors")
	assert_true(stats.text.contains("Systems: 0"), "HUD shows visible systems")
	assert_true(stats.text.contains("Zoom: 50.0"), "HUD shows initial zoom")
	camera.apply_zoom_steps(1)
	assert_true(stats.text.contains("Zoom: 44.0"), "HUD refreshes after zoom")
	demo.free()


func _test_reference_zoom_refreshes_stream_coverage() -> void:
	var demo = Demo.instantiate()
	Engine.get_main_loop().root.add_child(demo)
	var camera = demo.get_node("MapCamera")
	var stream = demo.get_node("SectorStreamController")
	camera.size = 300.0
	demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
	assert_equal(camera.size, 300.0, "coverage test uses its reference zoom")
	assert_equal(
		stream.load_radii,
		Vector2i(8, 5),
		"demo forwards reference 16:9 coverage"
	)
	demo.free()


func _test_viewport_resize_signal_refreshes_portrait_and_ultrawide_coverage() -> void:
	var demo = Demo.instantiate()
	demo._ready()
	var camera = demo.get_node("MapCamera")
	var stream = demo.get_node("SectorStreamController")
	camera.size = 300.0
	demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
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
