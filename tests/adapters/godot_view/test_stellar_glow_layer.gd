extends "res://tests/test_case.gd"

const Layer = preload("res://scripts/adapters/godot_view/stellar_glow_layer.gd")
const Settings = preload("res://config/game_settings.tres")

func run() -> void:
	var layer = Layer.new(Settings)
	layer.publish({
		"generation": 4,
		"transforms": [Transform3D(Basis.IDENTITY, Vector3(2, 0, 3))],
		"colors": [Color.RED],
		"custom_data": [Color(0.2, 0.5, 0.03, 0.7)],
	})
	assert_equal(layer.get_child_count(), 1, "layer owns one fixed multimesh node")
	assert_equal(layer.instance_count(), 1, "one profile becomes one instance")
	assert_equal(layer.published_generation, 4, "published generation is retained")
	assert_true(layer.multimesh_instance.multimesh.use_custom_data, "custom pulse data is enabled")
	layer.clear()
	assert_equal(layer.instance_count(), 0, "clear removes instances")
	layer.free()
