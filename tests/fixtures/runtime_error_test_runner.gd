extends SceneTree


func _initialize() -> void:
	print("TESTS PASSED")
	Callable(self, "missing_runtime_method").call()
	quit(0)
