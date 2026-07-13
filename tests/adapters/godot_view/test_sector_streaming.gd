extends "res://tests/test_case.gd"

const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const View = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const Controller = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const StarVisualType = preload("res://scripts/visuals/star_visual.gd")
const StarDefinitionType = preload("res://scripts/domain/universe/star_definition.gd")
const UniverseSectorType = preload("res://scripts/domain/universe/universe_sector.gd")


class CountingGenerator extends RefCounted:
	var calls_by_sector := {}
	var delegate = Generator.new()


	func generate_sector(coordinate):
		var key: String = coordinate.key()
		calls_by_sector[key] = calls_by_sector.get(key, 0) + 1
		return delegate.generate_sector(coordinate)


func run() -> void:
	_test_bounded_streaming_and_deterministic_rematerialization()
	_test_rapid_center_change_discards_stale_pending_sectors()
	_test_sector_placement_preserves_integer_precision()
	_test_unload_does_not_mutate_sector()
	_test_star_resources_are_shared_and_neutral_ring_is_not_configured()
	_test_stats_emit_only_when_observable_state_changes()
	_test_active_sector_is_not_regenerated()
	_test_invalid_visual_type_materializes_with_safe_fallback()


func _test_bounded_streaming_and_deterministic_rematerialization() -> void:
	var view = View.new()
	var controller = Controller.new()
	var generator = Generator.new()
	controller.configure(generator, view, PositionType.new(Coordinate.new(), Vector2.ZERO))
	controller.process_pending()
	assert_equal(view.active_sector_count(), 2, "default batch loads at most two sectors")
	controller.process_pending(100)
	assert_equal(view.active_sector_count(), 25, "load radius creates 25 sectors")
	assert_true(view.star_count() > 0, "stars are materialized")
	var original_signature = view.sector_signature(Coordinate.new())
	controller.update_center(PositionType.new(Coordinate.new(10, 0), Vector2.ZERO))
	controller.process_pending(100)
	assert_true(view.active_sector_count() <= 49, "active sectors stay bounded")
	assert_true(not view.has_sector(Coordinate.new()), "distant origin unloads")
	controller.update_center(PositionType.new(Coordinate.new(), Vector2.ZERO))
	controller.process_pending(100)
	assert_equal(
		view.sector_signature(Coordinate.new()),
		original_signature,
		"return rematerializes same stars"
	)
	controller.free()
	view.free()


func _test_rapid_center_change_discards_stale_pending_sectors() -> void:
	var view = View.new()
	var controller = Controller.new()
	controller.configure(
		Generator.new(),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_center(PositionType.new(Coordinate.new(100, 100), Vector2.ZERO))
	controller.process_pending(100)
	assert_equal(view.active_sector_count(), 25, "replacement center loads exactly one window")
	assert_true(not view.has_sector(Coordinate.new()), "stale origin queue is discarded")
	assert_true(view.has_sector(Coordinate.new(100, 100)), "latest center is materialized")
	controller.free()
	view.free()


func _test_sector_placement_preserves_integer_precision() -> void:
	var view = View.new()
	var large_coordinate := 9007199254740992
	var coordinate = Coordinate.new(large_coordinate + 1, large_coordinate - 1)
	view.materialize_sector(
		Generator.new().generate_sector(coordinate),
		Coordinate.new(large_coordinate, large_coordinate)
	)
	assert_equal(
		view.get_node("Sector_%d_%d" % [coordinate.x, coordinate.y]).position,
		Vector3(40.0, 0.0, -40.0),
		"sector offset uses integer difference before float conversion"
	)
	view.free()


func _test_unload_does_not_mutate_sector() -> void:
	var coordinate = Coordinate.new(3, -4)
	var sector = Generator.new().generate_sector(coordinate)
	var signature_before: Array = sector.stars.map(func(star): return String(star.id))
	var view = View.new()
	view.materialize_sector(sector, coordinate)
	view.remove_sector(coordinate)
	assert_equal(
		sector.stars.map(func(star): return String(star.id)),
		signature_before,
		"unload leaves UniverseSector contents unchanged"
	)
	view.free()


func _test_star_resources_are_shared_and_neutral_ring_is_not_configured() -> void:
	var first_visual = StarVisualType.new()
	var second_visual = StarVisualType.new()
	first_visual.configure(&"yellow")
	second_visual.configure(&"yellow")
	assert_true(
		first_visual.get_node("Body").mesh == second_visual.get_node("Body").mesh,
		"stars share mesh"
	)
	assert_true(
		first_visual.get_node("Body").material_override
		== second_visual.get_node("Body").material_override,
		"same star type shares material"
	)
	assert_true(not first_visual.get_node("OwnerRing").visible, "neutral star skips owner ring")
	assert_true(
		first_visual.get_node("OwnerRing/Body").mesh == null,
		"neutral star does not configure owner ring geometry"
	)
	first_visual.free()
	second_visual.free()


func _test_stats_emit_only_when_observable_state_changes() -> void:
	var view = View.new()
	var controller = Controller.new()
	var emissions := [0]
	controller.stats_changed.connect(func(_sectors, _stars, _center): emissions[0] += 1)
	controller.configure(
		Generator.new(),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	assert_equal(emissions[0], 1, "configuration emits initial stream stats")
	controller.process_pending(0)
	controller.process_pending(0)
	assert_equal(emissions[0], 1, "idle processing does not repeat unchanged stats")
	controller.process_pending(1)
	assert_equal(emissions[0], 2, "materialization emits changed stats")
	controller.process_pending(0)
	assert_equal(emissions[0], 2, "idle processing remains silent after a load")
	controller.free()
	view.free()


func _test_active_sector_is_not_regenerated() -> void:
	var generator = CountingGenerator.new()
	var view = View.new()
	var controller = Controller.new()
	var origin = PositionType.new(Coordinate.new(), Vector2.ZERO)
	controller.configure(generator, view, origin)
	controller.process_pending(100)
	var calls_after_load: Dictionary = generator.calls_by_sector.duplicate()
	controller.update_center(origin)
	controller.process_pending(100)
	assert_equal(
		generator.calls_by_sector,
		calls_after_load,
		"an active sector is not regenerated when the center remains unchanged"
	)
	controller.free()
	view.free()


func _test_invalid_visual_type_materializes_with_safe_fallback() -> void:
	var coordinate = Coordinate.new()
	var invalid_visual_star = StarDefinitionType.new(
		&"invalid_visual",
		coordinate,
		Vector2(4.0, 6.0),
		&"not_a_visual_type",
		&"isolated",
		coordinate,
		1
	)
	var yellow_star = StarDefinitionType.new(
		&"yellow_visual",
		coordinate,
		Vector2(8.0, 6.0),
		&"yellow",
		&"isolated",
		coordinate,
		2
	)
	var view = View.new()
	view.materialize_sector(
		UniverseSectorType.new(coordinate, [invalid_visual_star, yellow_star]),
		coordinate
	)
	var visual = view.get_node("Sector_0_0/invalid_visual")
	assert_true(visual.get_node("Body").mesh != null, "invalid visual type uses a safe mesh")
	assert_true(
		visual.get_node("Body").material_override != null,
		"invalid visual type uses a safe material"
	)
	assert_true(
		visual.get_node("Body").material_override
		== view.get_node("Sector_0_0/yellow_visual/Body").material_override,
		"invalid visual type reuses the canonical fallback material"
	)
	view.free()
