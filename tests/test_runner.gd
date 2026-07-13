extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/dependencies/test_sqlite_dependency.gd"),
	preload("res://tests/config/test_game_settings.gd"),
	preload("res://tests/application/catalog/test_catalog_contracts.gd"),
	preload("res://tests/application/catalog/test_catalog_validator.gd"),
	preload("res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd"),
	preload("res://tests/adapters/persistence/test_production_catalog.gd"),
	preload("res://tests/domain/universe/test_universe_coordinates.gd"),
	preload("res://tests/domain/universe/test_generation_foundations.gd"),
	preload("res://tests/domain/universe/test_stellar_system_definition.gd"),
	preload("res://tests/domain/universe/test_universe_generator.gd"),
	preload("res://tests/application/projections/test_visible_sector_projection.gd"),
	preload("res://tests/adapters/godot_view/test_map_camera_controller.gd"),
	preload("res://tests/adapters/godot_view/test_sector_streaming.gd"),
	preload("res://tests/visuals/test_visual_palette.gd"),
	preload("res://tests/visuals/test_geometric_components.gd"),
	preload("res://tests/demo/test_geometric_visual_demo.gd"),
	preload("res://tests/demo/test_infinite_star_map_demo.gd"),
]


func _initialize() -> void:
	var failures := 0
	var test_scripts := _selected_test_scripts()
	if test_scripts.is_empty():
		push_error("Requested test suite was not registered")
		quit(1)
		return
	for test_script in test_scripts:
		if not test_script.can_instantiate():
			failures += 1
			push_error("Test suite could not be instantiated: %s" % test_script.resource_path)
			continue
		var suite = test_script.new()
		suite.run()
		failures += suite.failures

	if failures == 0:
		print("TESTS PASSED")
	else:
		push_error("%d TESTS FAILED" % failures)
	quit(failures)


func _selected_test_scripts() -> Array:
	var requested_suite := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-suite="):
			requested_suite = argument.trim_prefix("--test-suite=")
	if requested_suite.is_empty():
		return TEST_SCRIPTS
	for test_script in TEST_SCRIPTS:
		if test_script.resource_path == requested_suite:
			return [test_script]
	return []
