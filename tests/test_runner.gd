extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/domain/universe/test_universe_coordinates.gd"),
	preload("res://tests/visuals/test_visual_palette.gd"),
	preload("res://tests/visuals/test_geometric_components.gd"),
	preload("res://tests/demo/test_geometric_visual_demo.gd"),
]


func _initialize() -> void:
	var failures := 0
	for test_script in TEST_SCRIPTS:
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
