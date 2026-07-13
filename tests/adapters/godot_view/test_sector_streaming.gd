extends "res://tests/test_case.gd"

const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const View = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const Controller = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const StarVisualType = preload("res://scripts/visuals/star_visual.gd")


func run() -> void:
	_test_bounded_streaming_and_deterministic_rematerialization()
	_test_rapid_center_change_discards_stale_pending_sectors()
	_test_sector_placement_preserves_integer_precision()
	_test_unload_does_not_mutate_sector()
	_test_star_resources_are_shared_and_neutral_ring_is_not_configured()


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
