extends "res://tests/test_case.gd"

const Builder = preload("res://scripts/application/rendering/stellar_glow_batch_builder.gd")
const Profile = preload("res://scripts/domain/universe/stellar_light_profile.gd")
const Settings = preload("res://config/game_settings.tres")

class Service:
	var calls := 0
	func execute(definition):
		calls += 1
		return Profile.new(definition.id, Color.WHITE, 1.0, 1.0, 0.2, 4.0, 0.02, 0.5)

class Definition:
	var id: StringName
	func _init(value): id = value

func run() -> void:
	var service = Service.new()
	var builder = Builder.new(service, Settings)
	var systems := []
	for index in 10:
		systems.append({"id": StringName("s%d" % index), "definition": Definition.new(StringName("s%d" % index)), "global_position": Vector2(index, 0)})
	builder.begin(7, Rect2(-1, -1, 20, 2), systems)
	assert_equal(builder.process(3), 3, "explicit budget limits profile work")
	assert_equal(service.calls, 3, "only budgeted profiles resolve")
	builder.process(20)
	assert_true(builder.is_complete(), "builder completes generation")
	assert_equal(builder.snapshot().transforms.size(), 10, "all transforms are prepared")
	builder.begin(8, Rect2(-1, -1, 2, 2), systems)
	assert_equal(builder.snapshot().generation, 8, "new generation replaces old state")
