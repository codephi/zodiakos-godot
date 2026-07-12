extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/visuals/test_visual_palette.gd"),
]


func _initialize() -> void:
	var failures := 0
	for test_script in TEST_SCRIPTS:
		var suite = test_script.new()
		suite.run()
		failures += suite.failures

	if failures == 0:
		print("TESTS PASSED")
	else:
		push_error("%d TESTS FAILED" % failures)
	quit(failures)
