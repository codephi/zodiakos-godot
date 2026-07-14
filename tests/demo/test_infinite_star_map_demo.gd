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
	_test_maximum_zoom_routes_fixed_grid_coverage()
	_test_runtime_stream_tuning_is_temporary_and_resettable()
	_test_minimap_composes_with_independent_queries()
	_test_minimap_camera_follow_and_negative_navigation()


func _test_composes_infinite_map_and_progressively_loads_initial_sectors() -> void:
	var demo = Demo.instantiate()
	var camera = demo.get_node_or_null("MapCamera")
	var stream = demo.get_node_or_null("SectorStreamController")
	var sector_root = demo.get_node_or_null("SectorRoot")
	assert_true(camera != null, "map camera exists")
	assert_true(stream != null, "stream controller exists")
	assert_true(sector_root != null, "sector root exists")
	assert_true(demo.get_node_or_null("DebugHud/Stats") != null, "debug HUD exists")
	assert_true(
		demo.get_node_or_null("DebugHud/StreamingDebugPanel") != null,
		"streaming debug panel exists"
	)
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
	assert_true(not stats.text.contains("SS Procedural:"), "catalog error omits SS metrics")
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
	assert_true(stats.text.contains("SS Procedural: avg --"), "HUD shows empty SS metrics")
	assert_true(stats.text.contains("SS Catalog: avg --"), "HUD separates catalog metrics")
	assert_true(stats.text.contains("SS Cache: hits 0"), "HUD shows cache metrics")
	demo.composition_metrics.record_success(&"procedural", 2.5)
	demo.refresh_debug_hud()
	assert_true(stats.text.contains("SS Procedural: avg 2.50 ms"), "HUD refreshes metrics")
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
		Vector2i(20, 12),
		"demo forwards reference 16:9 coverage"
	)
	demo.free()


func _test_maximum_zoom_routes_fixed_grid_coverage() -> void:
	var demo = Demo.instantiate()
	var stream = demo.get_node("SectorStreamController")
	demo.get_node("MapCamera").size = Settings.camera_max_zoom
	demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
	assert_equal(stream.load_radii, Vector2i(7, 4), "demo routes max zoom radii")
	assert_equal(stream.pending.size(), 135, "demo queues the complete nine viewport grid")
	demo.free()


func _test_runtime_stream_tuning_is_temporary_and_resettable() -> void:
	var original_fixed: bool = Settings.stream_use_fixed_preload_zoom
	var original_fixed_zoom: float = Settings.stream_fixed_preload_zoom
	var original_grid: int = Settings.stream_viewport_grid_size
	var demo = Demo.instantiate()
	assert_true(demo.runtime_settings != Settings, "demo uses a runtime settings copy")
	assert_true(
		demo.map_camera.settings == demo.runtime_settings,
		"camera shares runtime settings"
	)
	assert_true(demo.stream.settings == demo.runtime_settings, "stream shares runtime settings")
	assert_true(
		demo.sector_view.settings == demo.runtime_settings,
		"view shares runtime settings"
	)
	demo._apply_stream_tuning(true, 1000.0, 3, 0, 7)
	demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
	assert_equal(demo.stream.load_radii, Vector2i(67, 38), "panel tuning changes coverage")
	assert_equal(demo.stream.pending_sector_count(), 7, "panel tuning changes pending cap")
	assert_equal(
		Settings.stream_use_fixed_preload_zoom,
		original_fixed,
		"source fixed mode is untouched"
	)
	assert_equal(
		Settings.stream_fixed_preload_zoom,
		original_fixed_zoom,
		"source fixed zoom is untouched"
	)
	assert_equal(Settings.stream_viewport_grid_size, original_grid, "source grid is untouched")
	assert_true(
		demo.debug_panel.metrics_label.text.contains("Preload zoom: 1000.0"),
		"panel shows applied preload zoom"
	)
	assert_true(
		demo.debug_panel.metrics_label.text.contains("Target: 10395"),
		"panel shows applied target"
	)

	demo._apply_stream_tuning(true, 1000.0, 2, 2, 256)
	assert_equal(
		demo.runtime_settings.stream_viewport_grid_size,
		3,
		"invalid tuning preserves the last valid grid"
	)
	assert_true(not demo.debug_panel.error_label.text.is_empty(), "invalid tuning reports an error")
	demo._reset_stream_tuning()
	assert_equal(
		demo.runtime_settings.stream_use_fixed_preload_zoom,
		demo.session_default_settings.stream_use_fixed_preload_zoom,
		"reset restores session fixed mode"
	)
	assert_equal(
		demo.runtime_settings.stream_viewport_grid_size,
		demo.session_default_settings.stream_viewport_grid_size,
		"reset restores session grid"
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
		Vector2i(7, 12),
		"portrait resize provides portrait stream coverage"
	)
	demo._refresh_stream_coverage(Vector2(3200.0, 900.0))
	assert_equal(
		stream.load_radii,
		Vector2i(40, 12),
		"ultrawide resize refreshes stream coverage"
	)
	demo.free()


func _test_minimap_composes_with_independent_queries() -> void:
	var demo = Demo.instantiate()
	var minimap = demo.get_node_or_null("DebugHud/StellarMinimap")
	var controller = demo.get_node_or_null("MinimapController")
	assert_true(minimap != null, "stellar minimap exists in HUD")
	assert_true(controller != null, "minimap controller exists")
	assert_true(
		demo.minimap_query_service.repository == demo.catalog_repository,
		"minimap reuses the open catalog repository"
	)
	assert_true(
		demo.minimap_query_service.sector_source == demo.sector_source,
		"minimap reuses the deterministic sector source"
	)
	var pending_before: int = demo.stream.pending_sector_count()
	var active_before: int = demo.sector_view.active_sector_count()
	controller.process_pending(1)
	assert_equal(demo.stream.pending_sector_count(), pending_before, "minimap does not consume stream pending work")
	assert_equal(demo.sector_view.active_sector_count(), active_before, "minimap creates no 3D sectors")
	var snapshot: Dictionary = controller.snapshot()
	assert_true(snapshot.visible_rect.size.x > 0.0, "minimap receives visible camera bounds")
	assert_true(snapshot.preload_rect.size.x > snapshot.visible_rect.size.x, "minimap receives preload bounds")
	demo.free()


func _test_minimap_camera_follow_and_negative_navigation() -> void:
	var demo = Demo.instantiate()
	var camera = demo.get_node("MapCamera")
	var controller = demo.get_node("MinimapController")
	var position_type = preload("res://scripts/domain/universe/universe_position.gd")
	var coordinate_type = preload("res://scripts/domain/universe/sector_coordinate.gd")
	camera.set_logical_position(position_type.new(
		coordinate_type.new(-3, 1),
		Vector2(35.0, 5.0),
		demo.runtime_settings.universe_sector_size
	))
	assert_true(
		controller.projection.center_global.is_equal_approx(Vector2(-85.0, 45.0)),
		"camera movement updates minimap follow center"
	)
	demo._on_minimap_navigation(Vector2(-125.0, -45.0))
	assert_equal(camera.logical_position.sector.key(), "-4:-2", "negative target normalizes sector")
	assert_equal(camera.logical_position.local, Vector2(35.0, 35.0), "negative target normalizes local position")
	assert_equal(demo.stream.center.key(), "-4:-2", "minimap navigation updates stream center")
	demo.free()
