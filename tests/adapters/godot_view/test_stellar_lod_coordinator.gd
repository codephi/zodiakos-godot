extends "res://tests/test_case.gd"

const Coordinator = preload("res://scripts/adapters/godot_view/stellar_lod_coordinator.gd")
const Builder = preload("res://scripts/application/rendering/stellar_glow_batch_builder.gd")
const Layer = preload("res://scripts/adapters/godot_view/stellar_glow_layer.gd")
const Profile = preload("res://scripts/domain/universe/stellar_light_profile.gd")
const Settings = preload("res://config/game_settings.tres")

class Service:
	func execute(definition): return Profile.new(definition.id, Color.WHITE, 1, 1, 0, 4, 0.02, 0.5)
class Definition:
	var id: StringName
	func _init(value): id = value

func run() -> void:
	var layer = Layer.new(Settings)
	var builder = Builder.new(Service.new(), Settings)
	var coordinator = Coordinator.new(Settings, builder, layer)
	var systems := [{"id": &"one", "definition": Definition.new(&"one"), "global_position": Vector2.ZERO}]
	coordinator.notify_data_changed(systems)
	coordinator.update_camera(Vector2.ZERO, 199.0, Vector2(1000, 500))
	assert_equal(coordinator.mode, &"preparing_glow", "below 200 starts glow preparation")
	coordinator.process_pending(10)
	assert_equal(coordinator.mode, &"stellar_glow", "completed batch publishes glow")
	assert_equal(layer.instance_count(), 1, "published glow contains system")
	coordinator.update_camera(Vector2.ZERO, 210.0, Vector2(1000, 500))
	assert_equal(coordinator.mode, &"stellar_glow", "hysteresis keeps glow")
	coordinator.update_camera(Vector2.ZERO, 220.0, Vector2(1000, 500))
	assert_equal(coordinator.mode, &"points_2d", "220 clears glow")
	assert_equal(layer.instance_count(), 0, "2D mode clears batch")
	layer.free()
