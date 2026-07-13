extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")


func run() -> void:
	var generator = Generator.new()
	var coordinate = Coordinate.new(-2, 3)
	var first = generator.generate_sector(coordinate)
	var second = generator.generate_sector(coordinate)
	assert_equal(_signature(first), _signature(second), "same request is deterministic")

	var reversed = Generator.new()
	reversed.generate_sector(Coordinate.new(8, -5))
	assert_equal(
		_signature(first),
		_signature(reversed.generate_sector(coordinate)),
		"request order is irrelevant"
	)
	assert_true(
		_signature(first) != _signature(
			Generator.new(Config.GLOBAL_SEED + 1).generate_sector(coordinate)
		),
		"seed changes stars"
	)

	_assert_region_rules(generator, Coordinate.new(0, 0))
	_assert_region_rules(generator, Coordinate.new(-3, -4))
	_assert_region_rules(generator, Coordinate.new(1 << 40, -(1 << 40)))
	_assert_distant_request_order()
	_assert_exact_minimum_distance_is_valid(generator)
	_assert_resolution_uses_local_winners(generator)


func _signature(sector) -> Array:
	var result := []
	for star in sector.stars:
		result.append([String(star.id), star.local_position, String(star.visual_type), star.priority])
	return result


func _assert_region_rules(generator, center) -> void:
	var all_stars := []
	var ids := {}
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var sector = generator.generate_sector(center.offset(offset_x, offset_y))
			assert_true(sector.stars.size() <= Config.MAX_STARS_PER_SECTOR, "sector cap")
			for star in sector.stars:
				assert_true(not ids.has(star.id), "star id is unique")
				ids[star.id] = true
				assert_true(Config.VISUAL_TYPES.has(star.visual_type), "known visual type")
				all_stars.append(star)
	for index in all_stars.size():
		for other_index in range(index + 1, all_stars.size()):
			var left = all_stars[index]
			var right = all_stars[other_index]
			var delta_sector := Vector2(
				left.sector.x - right.sector.x,
				left.sector.y - right.sector.y
			)
			var delta = (
				delta_sector * Config.SECTOR_SIZE
				+ left.local_position
				- right.local_position
			)
			assert_true(
				delta.length() >= Config.MINIMUM_DISTANCE - 0.001,
				"global minimum distance"
			)


func _assert_distant_request_order() -> void:
	var coordinate = Coordinate.new(1 << 40, -(1 << 40))
	var expected = _signature(Generator.new().generate_sector(coordinate))
	var reordered = Generator.new()
	reordered.generate_sector(Coordinate.new(-(1 << 40), 1 << 40))
	assert_equal(
		expected,
		_signature(reordered.generate_sector(coordinate)),
		"distant request order is irrelevant"
	)


func _assert_exact_minimum_distance_is_valid(generator) -> void:
	var first = Generator.Candidate.new()
	first.id = &"first"
	first.position = Vector2.ZERO
	first.priority = 2
	var second = Generator.Candidate.new()
	second.id = &"second"
	second.position = Vector2(Config.MINIMUM_DISTANCE, 0.0)
	second.priority = 1
	var candidates := [first, second]
	assert_true(generator._is_local_winner(first, candidates), "exact minimum distance is valid")
	assert_true(generator._is_local_winner(second, candidates), "boundary candidates both survive")


func _assert_resolution_uses_local_winners(generator) -> void:
	assert_true(generator.has_method("_resolve_candidates"), "generator exposes local resolution")
	if not generator.has_method("_resolve_candidates"):
		return
	var winner = Generator.Candidate.new()
	winner.id = &"winner"
	winner.position = Vector2.ZERO
	winner.priority = 1
	var middle = Generator.Candidate.new()
	middle.id = &"middle"
	middle.position = Vector2(1.0, 0.0)
	middle.priority = 2
	var trailing = Generator.Candidate.new()
	trailing.id = &"trailing"
	trailing.position = Vector2(2.0, 0.0)
	trailing.priority = 3
	var resolved = generator._resolve_candidates([winner, middle, trailing])
	assert_equal(resolved.size(), 1, "local resolution rejects candidates beaten by any neighbor")
	assert_equal(resolved[0].id, &"winner", "lowest-priority local candidate survives")
