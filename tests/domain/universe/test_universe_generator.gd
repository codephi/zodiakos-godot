extends "res://tests/test_case.gd"

const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const CandidateGenerator = preload(
	"res://scripts/domain/universe/procedural_candidate_generator.gd"
)
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Density = preload("res://scripts/domain/universe/galactic_density_model.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Settings = preload("res://config/game_settings.tres")


class FakeRepository extends ScientificCatalogRepository:
	var catalog_metadata: CatalogMetadata
	var metadata_calls := 0


	func _init(value: CatalogMetadata) -> void:
		catalog_metadata = value


	func metadata() -> CatalogMetadata:
		metadata_calls += 1
		return catalog_metadata


func run() -> void:
	_test_universe_identity_is_stable_and_versioned()
	_test_every_output_setting_versions_the_identity()
	_test_procedural_candidates_are_deterministic_and_bounded()
	_test_candidate_generation_does_not_touch_global_random_state()
	_test_candidate_owner_is_defensively_copied()
	_test_candidate_count_follows_density_and_cap()
	_test_generator_reads_metadata_once_and_is_request_order_independent()
	_test_generator_emits_finite_local_procedural_systems()
	_test_generator_resolves_global_spacing_across_sector_boundaries()
	_test_generator_identity_and_output_are_versioned()
	_test_generator_is_finite_outside_the_halo()


func _test_universe_identity_is_stable_and_versioned() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var first = Identity.new(101, 7, metadata, Settings).value
	assert_equal(first, Identity.new(101, 7, metadata, Settings).value, "identity is stable")
	assert_true(first > 0, "identity is positive")
	assert_true(first <= (1 << 56) - 1, "identity fits in positive 56 bits")
	assert_true(first != Identity.new(102, 7, metadata, Settings).value, "seed versions identity")
	assert_true(first != Identity.new(101, 8, metadata, Settings).value, "generator versions identity")
	assert_true(
		first != Identity.new(101, 7, Metadata.new(99, 3, 3), Settings).value,
		"catalog versions identity without schema version"
	)
	assert_true(
		first != Identity.new(101, 7, Metadata.new(99, 2, 4), Settings).value,
		"coordinate model versions identity"
	)
	assert_equal(
		first,
		Identity.new(101, 7, Metadata.new(99, 2, 3), Settings).value,
		"schema version does not version the galaxy"
	)


func _test_every_output_setting_versions_the_identity() -> void:
	var baseline = Identity.new(101, 7, Metadata.new(1, 2, 3), Settings).value
	var changed_visual_types: Array[StringName] = [&"red", &"yellow"]
	var changed_visual_weights: Array[int] = [34, 25, 20, 15, 6]
	var changed_values := {
		&"galaxy_disk_radius_pc": Settings.galaxy_disk_radius_pc + 1.0,
		&"galaxy_halo_radius_pc": Settings.galaxy_halo_radius_pc + 1.0,
		&"galaxy_disk_scale_length_pc": Settings.galaxy_disk_scale_length_pc + 1.0,
		&"galaxy_bulge_scale_radius_pc": Settings.galaxy_bulge_scale_radius_pc + 1.0,
		&"galaxy_bar_half_length_pc": Settings.galaxy_bar_half_length_pc + 1.0,
		&"galaxy_bar_axis_ratio": Settings.galaxy_bar_axis_ratio + 0.01,
		&"galaxy_bar_angle_deg": Settings.galaxy_bar_angle_deg + 1.0,
		&"galaxy_spiral_arm_count": Settings.galaxy_spiral_arm_count + 1,
		&"galaxy_spiral_pitch_deg": Settings.galaxy_spiral_pitch_deg + 0.1,
		&"galaxy_spiral_arm_width_pc": Settings.galaxy_spiral_arm_width_pc + 1.0,
		&"galaxy_halo_weight": Settings.galaxy_halo_weight + 0.01,
		&"galaxy_max_candidate_systems_per_sector": (
			Settings.galaxy_max_candidate_systems_per_sector + 1
		),
		&"universe_sector_size": Settings.universe_sector_size + 1.0,
		&"universe_minimum_system_distance": Settings.universe_minimum_system_distance + 0.1,
		&"universe_visual_types": changed_visual_types,
		&"universe_visual_type_weights": changed_visual_weights,
	}
	for field: StringName in changed_values:
		var changed = Settings.duplicate(true)
		changed.set(field, changed_values[field])
		assert_true(
			baseline != Identity.new(101, 7, Metadata.new(1, 2, 3), changed).value,
			"%s versions identity" % field
		)


func _test_procedural_candidates_are_deterministic_and_bounded() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var identity = Identity.new(101, Settings.universe_generator_version, metadata, Settings)
	var generator = CandidateGenerator.new(identity, Density.new(Settings), metadata, Settings)
	var owner = Coordinate.new(-2, 3)
	var first: Array = generator.candidates_for_owner(owner)
	var other: Array = generator.candidates_for_owner(Coordinate.new(4, -5))
	var second: Array = generator.candidates_for_owner(owner)
	assert_equal(_candidate_signature(first), _candidate_signature(second), "candidate order is stable")
	assert_true(not first.is_empty(), "inhabited galaxy owner produces candidates")
	assert_true(not other.is_empty(), "interspersed owner produces candidates")
	var origin := Vector2(owner.x, owner.y) * Settings.universe_sector_size
	for index in first.size():
		var candidate = first[index]
		assert_equal(
			candidate.id,
			StringName("proc:1:2:-2:3:%d" % index),
			"candidate id is versioned and indexed"
		)
		assert_true(candidate.position.x >= origin.x, "candidate x includes owner minimum")
		assert_true(
			candidate.position.x < origin.x + Settings.universe_sector_size,
			"candidate x excludes owner maximum"
		)
		assert_true(candidate.position.y >= origin.y, "candidate y includes owner minimum")
		assert_true(
			candidate.position.y < origin.y + Settings.universe_sector_size,
			"candidate y excludes owner maximum"
		)
		assert_equal(candidate.source, &"procedural", "candidate source is procedural")
		assert_true(Settings.universe_visual_types.has(candidate.visual_type), "visual is configured")
		assert_true(candidate.priority >= 0, "priority is nonnegative")


func _test_candidate_generation_does_not_touch_global_random_state() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var identity = Identity.new(101, Settings.universe_generator_version, metadata, Settings)
	var generator = CandidateGenerator.new(identity, Density.new(Settings), metadata, Settings)
	seed(90210)
	var expected := randf()
	seed(90210)
	generator.candidates_for_owner(Coordinate.new(0, 0))
	assert_equal(randf(), expected, "candidate generation does not consume global RNG")


func _test_candidate_owner_is_defensively_copied() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var identity = Identity.new(101, Settings.universe_generator_version, metadata, Settings)
	var generator = CandidateGenerator.new(identity, Density.new(Settings), metadata, Settings)
	var owner = Coordinate.new(0, 0)
	var candidates: Array = generator.candidates_for_owner(owner)
	assert_true(not candidates.is_empty(), "center provides a candidate for defensive-copy test")
	if candidates.is_empty():
		return
	owner.x = 100
	var leaked_owner = candidates[0].owner
	leaked_owner.y = 100
	assert_equal(candidates[0].owner.key(), "0:0", "candidate owner is immutable from callers")


func _test_candidate_count_follows_density_and_cap() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var identity = Identity.new(101, Settings.universe_generator_version, metadata, Settings)
	var density = Density.new(Settings)
	var generator = CandidateGenerator.new(identity, density, metadata, Settings)
	var owner = Coordinate.new(0, 0)
	var center := Vector2(0.5, 0.5) * Settings.universe_sector_size
	var raw_count: float = (
		density.density_at(center) * Settings.galaxy_max_candidate_systems_per_sector
	)
	var actual_count: int = generator.candidates_for_owner(owner).size()
	assert_true(
		actual_count == floori(raw_count) or actual_count == ceili(raw_count),
		"stochastic rounding chooses an adjacent integer"
	)
	assert_true(
		actual_count <= Settings.galaxy_max_candidate_systems_per_sector,
		"candidate count never exceeds cap"
	)
	assert_equal(
		generator.candidates_for_owner(Coordinate.new(2000, 2000)).size(),
		0,
		"outside halo produces zero candidates"
	)


func _candidate_signature(candidates: Array) -> Array:
	var result := []
	for candidate in candidates:
		result.append(
			[
				candidate.id,
				candidate.position,
				candidate.visual_type,
				candidate.source,
				candidate.owner.key(),
				candidate.priority,
			]
		)
	return result


func _test_generator_reads_metadata_once_and_is_request_order_independent() -> void:
	var repository = FakeRepository.new(Metadata.new(1, 2, 3))
	var generator = Generator.new(repository, Settings, 101)
	assert_equal(repository.metadata_calls, 1, "generator reads catalog metadata once")
	var coordinate = Coordinate.new(-2, 3)
	var first := _sector_signature(generator.generate_sector(coordinate))
	generator.generate_sector(Coordinate.new(8, -5))
	assert_equal(
		_sector_signature(generator.generate_sector(coordinate)),
		first,
		"request order does not change a sector"
	)
	assert_equal(repository.metadata_calls, 1, "generation reuses captured metadata")


func _test_generator_emits_finite_local_procedural_systems() -> void:
	var generator = Generator.new(FakeRepository.new(Metadata.new(1, 2, 3)), Settings, 101)
	var sector = generator.generate_sector(Coordinate.new(0, 0))
	assert_true(not sector.systems.is_empty(), "galactic center sector contains systems")
	assert_true(
		sector.systems.size() <= Settings.galaxy_max_candidate_systems_per_sector,
		"resolved systems remain below candidate cap"
	)
	for system in sector.systems:
		assert_true(is_finite(system.local_position.x), "local x is finite")
		assert_true(is_finite(system.local_position.y), "local y is finite")
		assert_true(system.local_position.x >= 0.0, "local x includes sector minimum")
		assert_true(system.local_position.y >= 0.0, "local y includes sector minimum")
		assert_true(system.local_position.x < Settings.universe_sector_size, "local x excludes max")
		assert_true(system.local_position.y < Settings.universe_sector_size, "local y excludes max")
		assert_equal(system.source, &"procedural", "system source is procedural")
		assert_equal(system.galactocentric_z_pc, 0.0, "procedural systems stay on the map plane")


func _test_generator_resolves_global_spacing_across_sector_boundaries() -> void:
	var generator = Generator.new(FakeRepository.new(Metadata.new(1, 2, 3)), Settings, 101)
	var systems := []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var sector = generator.generate_sector(Coordinate.new(x, y))
			for system in sector.systems:
				systems.append(system)
	for index in systems.size():
		for other_index in range(index + 1, systems.size()):
			var left = systems[index]
			var right = systems[other_index]
			var left_global: Vector2 = (
				Vector2(left.sector.x, left.sector.y) * Settings.universe_sector_size
				+ left.local_position
			)
			var right_global: Vector2 = (
				Vector2(right.sector.x, right.sector.y) * Settings.universe_sector_size
				+ right.local_position
			)
			assert_true(
				left_global.distance_to(right_global)
				>= Settings.universe_minimum_system_distance - 0.0001,
				"global systems respect spacing across sector borders"
			)


func _test_generator_identity_and_output_are_versioned() -> void:
	var base = Generator.new(FakeRepository.new(Metadata.new(1, 2, 3)), Settings, 101)
	var changed_seed = Generator.new(FakeRepository.new(Metadata.new(1, 2, 3)), Settings, 102)
	var changed_catalog = Generator.new(FakeRepository.new(Metadata.new(1, 3, 3)), Settings, 101)
	var changed_coordinates = Generator.new(
		FakeRepository.new(Metadata.new(1, 2, 4)), Settings, 101
	)
	var changed_settings = Settings.duplicate(true)
	changed_settings.universe_generator_version += 1
	var changed_generator = Generator.new(
		FakeRepository.new(Metadata.new(1, 2, 3)), changed_settings, 101
	)
	var coordinate = Coordinate.new(0, 0)
	var base_output := _sector_signature(base.generate_sector(coordinate))
	for changed in [changed_seed, changed_catalog, changed_coordinates, changed_generator]:
		assert_true(base.identity.value != changed.identity.value, "version input changes identity")
		assert_true(
			base_output != _sector_signature(changed.generate_sector(coordinate)),
			"version input changes procedural output"
		)


func _test_generator_is_finite_outside_the_halo() -> void:
	var generator = Generator.new(FakeRepository.new(Metadata.new(1, 2, 3)), Settings, 101)
	assert_equal(
		generator.generate_sector(Coordinate.new(2000, 2000)).systems.size(),
		0,
		"far outside the finite halo is empty"
	)


func _sector_signature(sector) -> Array:
	var result := []
	for system in sector.systems:
		result.append(
			[
				system.id,
				system.local_position,
				system.visual_type,
				system.source,
				system.owner_sector.key(),
				system.priority,
			]
		)
	return result
