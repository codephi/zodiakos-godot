extends "res://tests/test_case.gd"

const Controller = preload("res://scripts/adapters/godot_view/minimap_controller.gd")
const Settings = preload("res://config/game_settings.tres")


class FakeQueryService:
	var exact_calls := 0
	var catalog_calls := 0
	var cell_calls := 0


	func exact_points(coordinate) -> Array:
		exact_calls += 1
		return [{
			"id": StringName(coordinate.key()),
			"position": Vector2(coordinate.x, coordinate.y) * 40.0,
			"visual_type": &"yellow",
			"source": &"procedural",
		}]


	func catalog_points(_bounds: Rect2) -> Array:
		catalog_calls += 1
		return []


	func sample_cell(bounds: Rect2, resolution: int, index: int, mode: StringName) -> Dictionary:
		cell_calls += 1
		var cell_size := bounds.size / float(resolution)
		var x := index % resolution
		var y := index / resolution
		return {
			"rect": Rect2(bounds.position + Vector2(x, y) * cell_size, cell_size),
			"position": bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_size,
			"density": 0.5,
			"estimated_count": 3 if mode == &"cluster" else 0,
		}


func run() -> void:
	_test_initial_coverage_exact_budget_and_stale_generation()
	_test_cluster_and_density_budgets()
	_test_navigation_follow_and_cursor_zoom()


func _settings():
	var custom = Settings.duplicate(true)
	custom.minimap_initial_view_scale = 1.0
	custom.minimap_min_view_height = 40.0
	custom.minimap_max_view_height = 120000.0
	custom.minimap_query_sectors_per_frame = 8
	custom.minimap_density_cells_per_frame = 128
	return custom


func _test_initial_coverage_exact_budget_and_stale_generation() -> void:
	var service = FakeQueryService.new()
	var controller = Controller.new(_settings())
	controller.configure(service, Vector2.ZERO, 40.0, 1.0, 40.0)
	assert_equal(controller.projection.view_height, 44.0, "initial view fits preload with padding")
	assert_equal(controller.lod, &"exact", "small initial bounds use exact LOD")
	var token: int = controller.generation_id
	assert_equal(controller.process_pending(2, token), 2, "exact processing respects explicit budget")
	assert_equal(service.exact_calls, 2, "exact budget limits sector queries")
	controller.pan_pixels(Vector2(10.0, 0.0), Vector2(320.0, 220.0))
	assert_true(controller.generation_id > token, "panning creates a new generation")
	assert_equal(controller.process_pending(8, token), 0, "stale generation publishes no work")
	controller.free()


func _test_cluster_and_density_budgets() -> void:
	var cluster_settings = _settings()
	cluster_settings.minimap_exact_sector_limit = 1
	cluster_settings.minimap_cluster_sector_limit = 1000
	cluster_settings.minimap_cluster_grid_resolution = 4
	var cluster_service = FakeQueryService.new()
	var cluster = Controller.new(cluster_settings)
	cluster.configure(cluster_service, Vector2.ZERO, 400.0, 1.0, 400.0)
	assert_equal(cluster.lod, &"cluster", "medium bounds use cluster LOD")
	assert_equal(cluster.process_pending(3), 3, "cluster processing respects cell budget")
	assert_equal(cluster_service.cell_calls, 3, "cluster samples only requested cells")
	assert_equal(cluster_service.catalog_calls, 1, "cluster queries catalog once per generation")
	cluster.free()

	var density_settings = _settings()
	density_settings.minimap_exact_sector_limit = 1
	density_settings.minimap_cluster_sector_limit = 2
	density_settings.minimap_density_grid_resolution = 4
	var density_service = FakeQueryService.new()
	var density = Controller.new(density_settings)
	density.configure(density_service, Vector2.ZERO, 400.0, 1.0, 400.0)
	assert_equal(density.lod, &"density", "large bounds use density LOD")
	assert_equal(density.process_pending(3), 3, "density processing respects cell budget")
	assert_equal(density_service.cell_calls, 3, "density samples only requested cells")
	density.free()


func _test_navigation_follow_and_cursor_zoom() -> void:
	var controller = Controller.new(_settings())
	controller.configure(FakeQueryService.new(), Vector2(100.0, 200.0), 100.0, 2.0, 100.0)
	var visible := Rect2(50.0, 150.0, 100.0, 100.0)
	var preload_bounds := Rect2(-100.0, 0.0, 400.0, 400.0)
	controller.set_main_camera_state(Vector2(100.0, 200.0), visible, preload_bounds, 2.0)
	assert_equal(controller.snapshot().visible_rect, visible, "snapshot keeps visible overlay")
	assert_equal(controller.snapshot().preload_rect, preload_bounds, "snapshot keeps preload overlay")
	controller.pan_pixels(Vector2(20.0, 0.0), Vector2(320.0, 220.0))
	assert_true(not controller.follow_main_camera, "panning disables camera follow")
	controller.center_on_main_camera()
	assert_true(controller.follow_main_camera, "centering restores camera follow")
	assert_equal(controller.projection.center_global, Vector2(100.0, 200.0), "centering uses camera")

	var drawing_rect := Rect2(Vector2.ZERO, Vector2(320.0, 220.0))
	var cursor := Vector2(240.0, 110.0)
	var anchored_before: Vector2 = controller.projection.pixel_to_world(cursor, drawing_rect)
	controller.zoom_steps_at(1, cursor, drawing_rect)
	assert_true(
		controller.projection.pixel_to_world(cursor, drawing_rect).is_equal_approx(anchored_before),
		"controller zoom stays anchored"
	)
	var requested: Array[Vector2] = []
	controller.navigation_requested.connect(func(target: Vector2): requested.append(target))
	controller.navigate_to(Vector2(-85.0, 45.0))
	assert_equal(requested, [Vector2(-85.0, 45.0)], "navigation emits global target")
	assert_true(controller.follow_main_camera, "navigation restores follow")
	controller.free()
