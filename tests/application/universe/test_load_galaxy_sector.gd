extends "res://tests/test_case.gd"

const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const LoadGalaxySector = preload("res://scripts/application/universe/load_galaxy_sector.gd")


class FakeCandidate extends RefCounted:
	var id: StringName
	var position: Vector2
	var visual_type: StringName
	var source: StringName = &"procedural"
	var owner: SectorCoordinate
	var priority: int


	func _init(
		candidate_id: StringName,
		global_position: Vector2,
		owner_sector: SectorCoordinate,
		candidate_priority: int,
		type: StringName = &"white"
	) -> void:
		id = candidate_id
		position = global_position
		owner = owner_sector
		priority = candidate_priority
		visual_type = type


class FakeRepository extends ScientificCatalogRepository:
	var anchors: Array[SystemAnchor] = []
	var requested_bounds: Array[Rect2] = []


	func _init(values: Array) -> void:
		anchors.assign(values)


	func systems_in_bounds(bounds: Rect2) -> Array[SystemAnchor]:
		requested_bounds.append(bounds)
		var result: Array[SystemAnchor] = []
		for anchor in anchors:
			if _inside_half_open(bounds, anchor.map_position()):
				result.append(anchor)
		return result


	func _inside_half_open(bounds: Rect2, position: Vector2) -> bool:
		return (
			position.x >= bounds.position.x
			and position.y >= bounds.position.y
			and position.x < bounds.end.x
			and position.y < bounds.end.y
		)


class FakeGenerator extends RefCounted:
	var candidates: Array = []
	var requested_bounds: Array[Rect2] = []
	var configured_sector_size := 40.0
	var configured_spacing := 1.5
	var configured_version := 7
	var configured_visual_type: StringName = &"yellow"


	func _init(values: Array) -> void:
		candidates = values.duplicate()


	func procedural_candidates_in_bounds(bounds: Rect2) -> Array:
		requested_bounds.append(bounds)
		var result := []
		for candidate in candidates:
			if _inside_half_open(bounds, candidate.position):
				result.append(candidate)
		return result


	func sector_size() -> float:
		return configured_sector_size


	func minimum_system_distance() -> float:
		return configured_spacing


	func generator_version() -> int:
		return configured_version


	func default_visual_type() -> StringName:
		return configured_visual_type


	func _inside_half_open(bounds: Rect2, position: Vector2) -> bool:
		return (
			position.x >= bounds.position.x
			and position.y >= bounds.position.y
			and position.x < bounds.end.x
			and position.y < bounds.end.y
		)


func run() -> void:
	_test_sol_keeps_catalog_identity_and_scientific_position()
	_test_catalog_anchors_all_survive_and_suppress_procedural_candidates()
	_test_procedural_priority_and_id_resolve_border_conflicts_deterministically()
	_test_pairwise_local_winner_prevents_chain_acceptance()
	_test_negative_coordinates_and_half_open_edges_have_one_owner()
	_test_use_case_snapshots_generator_scalars()


func _test_sol_keeps_catalog_identity_and_scientific_position() -> void:
	var sol = _anchor(&"catalog:sol", Vector3(8150.0, 0.0, 20.8))
	var repository = FakeRepository.new([sol])
	var generator = FakeGenerator.new([])
	var loader = LoadGalaxySector.new(repository, generator)
	var sector = loader.generate_sector(Coordinate.new(203, 0))
	var projected = _find_system(sector.systems, &"catalog:sol")

	assert_true(projected != null, "Sol appears in its galactocentric sector")
	if projected != null:
		assert_equal(projected.local_position, Vector2(30.0, 0.0), "Sol is sector-local")
		assert_equal(projected.source, &"catalog", "Sol retains catalog source")
		assert_equal(projected.id, &"catalog:sol", "Sol retains its stable catalog id")
		assert_equal(projected.priority, -1, "catalog systems have absolute priority")
		assert_equal(
			projected.galactocentric_z_pc,
			sol.galactocentric_position.z,
			"Sol preserves scientific z without changing the catalog value"
		)
		assert_true(
			absf(projected.galactocentric_z_pc - 20.8) < 0.0001,
			"Sol scientific z remains approximately 20.8 pc"
		)
	assert_equal(
		repository.requested_bounds[0],
		Rect2(Vector2(8118.5, -1.5), Vector2(43.0, 43.0)),
		"catalog query grows target bounds by the spacing snapshot"
	)
	assert_equal(
		generator.requested_bounds[0],
		repository.requested_bounds[0],
		"catalog and procedural generation share the same global margin"
	)


func _test_catalog_anchors_all_survive_and_suppress_procedural_candidates() -> void:
	var sol = _anchor(&"catalog:sol", Vector3(8150.0, 10.0, 20.8))
	var neighbor = _anchor(&"catalog:neighbor", Vector3(8150.5, 10.0, -3.0))
	var candidates := [
		_candidate(&"proc:near", Vector2(8150.75, 10.0), Coordinate.new(203, 0), 0),
		_candidate(&"proc:far", Vector2(8155.0, 10.0), Coordinate.new(203, 0), 1),
	]
	var loader = LoadGalaxySector.new(
		FakeRepository.new([sol, neighbor]),
		FakeGenerator.new(candidates)
	)
	var systems = loader.generate_sector(Coordinate.new(203, 0)).systems

	assert_true(_find_system(systems, &"catalog:sol") != null, "first close anchor remains")
	assert_true(_find_system(systems, &"catalog:neighbor") != null, "second close anchor remains")
	assert_equal(_find_system(systems, &"proc:near"), null, "anchor suppresses nearby procedural")
	var far = _find_system(systems, &"proc:far")
	assert_true(far != null, "nonconflicting procedural remains")
	if far != null:
		assert_equal(far.source, &"procedural", "generated system keeps procedural source")
		assert_equal(far.galactocentric_z_pc, 0.0, "procedural system stays on map plane")


func _test_procedural_priority_and_id_resolve_border_conflicts_deterministically() -> void:
	var border_candidates := [
		_candidate(&"proc:left", Vector2(39.7, 10.0), Coordinate.new(0, 0), 20),
		_candidate(&"proc:right", Vector2(40.3, 10.0), Coordinate.new(1, 0), 10),
	]
	var loader = LoadGalaxySector.new(FakeRepository.new([]), FakeGenerator.new(border_candidates))
	var forward_left := _system_ids(loader.generate_sector(Coordinate.new(0, 0)).systems)
	var forward_right := _system_ids(loader.generate_sector(Coordinate.new(1, 0)).systems)
	var reverse_right := _system_ids(loader.generate_sector(Coordinate.new(1, 0)).systems)
	var reverse_left := _system_ids(loader.generate_sector(Coordinate.new(0, 0)).systems)

	assert_equal(forward_left, reverse_left, "left border result ignores request order")
	assert_equal(forward_right, reverse_right, "right border result ignores request order")
	assert_equal(forward_left, [], "higher numeric priority loses across the border")
	assert_equal(forward_right, [&"proc:right"], "lower numeric priority wins across the border")

	var tied := [
		_candidate(&"proc:zeta", Vector2(10.0, 10.0), Coordinate.new(0, 0), 5),
		_candidate(&"proc:alpha", Vector2(10.5, 10.0), Coordinate.new(0, 0), 5),
	]
	var tied_loader = LoadGalaxySector.new(FakeRepository.new([]), FakeGenerator.new(tied))
	assert_equal(
		_system_ids(tied_loader.generate_sector(Coordinate.new(0, 0)).systems),
		[&"proc:alpha"],
		"lexicographically lower id breaks equal priorities"
	)


func _test_pairwise_local_winner_prevents_chain_acceptance() -> void:
	var chain := [
		_candidate(&"proc:a", Vector2(10.0, 10.0), Coordinate.new(0, 0), 1),
		_candidate(&"proc:b", Vector2(11.0, 10.0), Coordinate.new(0, 0), 2),
		_candidate(&"proc:c", Vector2(12.0, 10.0), Coordinate.new(0, 0), 3),
	]
	var loader = LoadGalaxySector.new(FakeRepository.new([]), FakeGenerator.new(chain))
	assert_equal(
		_system_ids(loader.generate_sector(Coordinate.new(0, 0)).systems),
		[&"proc:a"],
		"every candidate loses to any better local contender, including a rejected one"
	)


func _test_negative_coordinates_and_half_open_edges_have_one_owner() -> void:
	var negative = _anchor(&"catalog:negative", Vector3(-0.1, 5.0, 1.0))
	var boundary = _anchor(&"catalog:boundary", Vector3(0.0, 5.0, 2.0))
	var loader = LoadGalaxySector.new(FakeRepository.new([negative, boundary]), FakeGenerator.new([]))

	assert_equal(
		_system_ids(loader.generate_sector(Coordinate.new(-1, 0)).systems),
		[&"catalog:negative"],
		"negative point maps to the negative owner and excludes the maximum edge"
	)
	assert_equal(
		_system_ids(loader.generate_sector(Coordinate.new(0, 0)).systems),
		[&"catalog:boundary"],
		"exact boundary belongs to the next sector"
	)


func _test_use_case_snapshots_generator_scalars() -> void:
	var repository = FakeRepository.new([])
	var generator = FakeGenerator.new([])
	var loader = LoadGalaxySector.new(repository, generator)
	generator.configured_sector_size = 100.0
	generator.configured_spacing = 9.0
	generator.configured_version = 99
	generator.configured_visual_type = &"red"

	var sector = loader.generate_sector(Coordinate.new(1, 0))
	assert_equal(
		repository.requested_bounds[0],
		Rect2(Vector2(38.5, -1.5), Vector2(43.0, 43.0)),
		"use case remains bound to construction-time sector size and spacing"
	)
	assert_equal(sector.generator_version, 7, "use case snapshots generator version")


func _anchor(id: StringName, position: Vector3):
	return Anchor.new(id, String(id), "", position)


func _candidate(id: StringName, position: Vector2, owner: SectorCoordinate, priority: int):
	return FakeCandidate.new(id, position, owner, priority)


func _find_system(systems: Array, id: StringName):
	for system in systems:
		if system.id == id:
			return system
	return null


func _system_ids(systems: Array) -> Array:
	return systems.map(func(system): return system.id)
