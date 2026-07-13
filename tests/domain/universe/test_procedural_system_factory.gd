extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Factory = preload("res://scripts/domain/universe/procedural_system_factory.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Naming = preload("res://scripts/domain/universe/dynamic_naming_service.gd")
const Settings = preload("res://config/game_settings.tres")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")

const MINOR_TYPES: Array[StringName] = [
	&"asteroid",
	&"comet",
	&"dwarf_planet",
	&"trans_neptunian",
	&"meteoroid",
	&"interstellar_object",
]


func run() -> void:
	_test_seed_mixer_frames_text_and_is_bounded()
	_test_composition_is_deterministic_and_identity_versioned()
	_test_generation_ignores_request_order_global_rng_and_z()
	_test_factory_snapshots_mutable_configuration()
	_test_counts_types_and_ids_respect_configuration()
	_test_structure_names_and_orbits_are_consistent()
	_test_minor_body_ordinals_are_local_to_type()
	_test_full_system_id_distinguishes_same_coordinate_names()


func _test_seed_mixer_frames_text_and_is_bounded() -> void:
	var first: int = SeedMixer.mix_text(42, "ab|c")
	assert_equal(first, SeedMixer.mix_text(42, "ab|c"), "text seed is stable")
	assert_true(first > 0, "text seed is positive")
	assert_true(first <= (1 << 56) - 1, "text seed fits in positive 56 bits")
	assert_true(first != SeedMixer.mix_text(42, "a|bc"), "text framing is unambiguous")
	assert_true(first != SeedMixer.mix_text(43, "ab|c"), "base seed changes text seed")


func _test_composition_is_deterministic_and_identity_versioned() -> void:
	var factory = Factory.new()
	var system = _system(&"proc:1:2:-7:9:4", Coordinate.new(-7, 9), Vector2(3.4, 5.6))
	var identity = _identity(101)
	var first := _signature(factory.create(system, identity))
	assert_equal(first, _signature(factory.create(system, identity)), "same request is stable")
	assert_true(
		first != _signature(factory.create(system, _identity(102))),
		"different universe identity changes composition"
	)


func _test_generation_ignores_request_order_global_rng_and_z() -> void:
	var factory = Factory.new()
	var identity = _identity(101)
	var requested = _system(&"proc:1:2:2:-3:5", Coordinate.new(2, -3), Vector2(1.2, 4.8))
	var same_without_z = System.new(
		requested.id,
		requested.sector,
		requested.local_position,
		requested.visual_type,
		requested.source,
		requested.owner_sector,
		requested.priority,
		requested.generator_version,
		0.0
	)
	var expected := _signature(factory.create(requested, identity))
	factory.create(
		_system(&"proc:1:2:100:100:0", Coordinate.new(100, 100), Vector2(9.0, 9.0)),
		identity
	)
	assert_equal(_signature(factory.create(requested, identity)), expected, "request order is irrelevant")
	assert_equal(
		_signature(factory.create(same_without_z, identity)),
		expected,
		"map-plane z does not affect procedural composition"
	)
	seed(90210)
	var expected_global := randf()
	seed(90210)
	factory.create(requested, identity)
	assert_equal(randf(), expected_global, "factory does not consume global random state")


func _test_factory_snapshots_mutable_configuration() -> void:
	var mutable = Settings.duplicate(true)
	var identity = Identity.new(
		101,
		mutable.universe_generator_version,
		Metadata.new(1, 2, 3),
		mutable
	)
	var factory = Factory.new()
	var system = _system(&"proc:1:2:0:0:7", Coordinate.new(0, 0), Vector2(2.0, 3.0))
	var before := _signature(factory.create(system, identity))
	mutable.universe_sector_size = 999.0
	mutable.system_min_stars = 3
	mutable.system_max_stars = 3
	mutable.system_max_planets = 0
	mutable.system_max_moons_per_planet = 0
	mutable.system_max_minor_bodies = 0
	mutable.universe_visual_types[0] = &"blue"
	mutable.universe_visual_type_weights[0] = 1
	mutable.system_planet_types[0] = &"gas"
	mutable.system_planet_type_weights[0] = 1
	var exposed_snapshot: Dictionary = identity.configuration_snapshot()
	exposed_snapshot.universe_sector_size = -1.0
	exposed_snapshot.universe_visual_types[0] = &"orange"
	assert_equal(
		_signature(factory.create(system, identity)),
		before,
		"factory remains bound to the identity-owned snapshot"
	)
	assert_equal(
		identity.configuration_snapshot().universe_sector_size,
		Settings.universe_sector_size,
		"identity protects returned scalar snapshot values"
	)
	assert_equal(
		identity.configuration_snapshot().universe_visual_types[0],
		Settings.universe_visual_types[0],
		"identity protects returned snapshot arrays"
	)
	var public_properties: Array = factory.get_property_list().map(
		func(property: Dictionary): return property["name"]
	)
	assert_true(not public_properties.has(&"settings"), "mutable settings are encapsulated")


func _test_counts_types_and_ids_respect_configuration() -> void:
	var factory = Factory.new()
	var identity = _identity(101)
	var all_ids := {}
	var saw_star_max := false
	var saw_planet_max := false
	var saw_moon_max := false
	var saw_minor_max := false
	for index in range(256):
		var system = _system(
			StringName("proc:1:2:0:0:%d" % index),
			Coordinate.new(0, 0),
			Vector2(float(index % 20), float(index / 20))
		)
		var composition = factory.create(system, identity)
		assert_true(
			composition.stars.size() >= Settings.system_min_stars
			and composition.stars.size() <= Settings.system_max_stars,
			"star count remains inside configured range"
		)
		assert_true(composition.planets.size() <= Settings.system_max_planets, "planet cap")
		assert_true(composition.minor_bodies.size() <= Settings.system_max_minor_bodies, "minor cap")
		saw_star_max = saw_star_max or composition.stars.size() == Settings.system_max_stars
		saw_planet_max = saw_planet_max or composition.planets.size() == Settings.system_max_planets
		saw_minor_max = saw_minor_max or composition.minor_bodies.size() == Settings.system_max_minor_bodies
		for star in composition.stars:
			assert_true(Settings.universe_visual_types.has(star.subtype), "star type is configured")
			_assert_unique_id(star.id, all_ids)
		for planet in composition.planets:
			assert_true(Settings.system_planet_types.has(planet.subtype), "planet type is configured")
			_assert_unique_id(planet.id, all_ids)
		for moon in composition.moons:
			_assert_unique_id(moon.id, all_ids)
		for minor in composition.minor_bodies:
			assert_true(MINOR_TYPES.has(minor.subtype), "minor type is supported")
			_assert_unique_id(minor.id, all_ids)
		var moons_per_planet := {}
		for moon in composition.moons:
			moons_per_planet[moon.parent_id] = moons_per_planet.get(moon.parent_id, 0) + 1
		for count: int in moons_per_planet.values():
			assert_true(count <= Settings.system_max_moons_per_planet, "per-planet moon cap")
			saw_moon_max = saw_moon_max or count == Settings.system_max_moons_per_planet
	assert_true(saw_star_max, "deterministic sample reaches star maximum")
	assert_true(saw_planet_max, "deterministic sample reaches planet maximum")
	assert_true(saw_moon_max, "deterministic sample reaches moon maximum")
	assert_true(saw_minor_max, "deterministic sample reaches minor maximum")


func _test_structure_names_and_orbits_are_consistent() -> void:
	var factory = Factory.new()
	var identity = _identity(101)
	var naming = Naming.new()
	var system = _find_rich_system(factory, identity)
	var composition = factory.create(system, identity)
	var global_position: Vector2 = (
		Vector2(system.sector.x, system.sector.y) * Settings.universe_sector_size
		+ system.local_position
	)
	var system_name := naming.system_designation(
		global_position,
		SeedMixer.mix_text(identity.value, String(system.id) + ":system-ordinal")
	)
	var primary = composition.stars[0]
	assert_equal(primary.parent_id, &"", "primary star has no parent")
	assert_equal(primary.designation, naming.star_designation(system_name, 0), "primary name")
	var bodies := {}
	for body in composition.stars + composition.planets + composition.moons + composition.minor_bodies:
		bodies[body.id] = body
	for index in composition.stars.size():
		var star = composition.stars[index]
		assert_equal(star.id, StringName("%s:star:%d" % [system.id, index]), "star id suffix")
		assert_equal(star.designation, naming.star_designation(system_name, index), "star name")
		assert_equal(star.parent_id, &"" if index == 0 else primary.id, "stellar parent")
	for index in composition.planets.size():
		var planet = composition.planets[index]
		assert_equal(planet.id, StringName("%s:planet:%d" % [system.id, index]), "planet id suffix")
		assert_equal(planet.designation, naming.planet_designation(system_name, index), "planet name")
		assert_equal(planet.parent_id, primary.id, "planet parent is primary star")
	for index in composition.moons.size():
		var moon = composition.moons[index]
		assert_true(bodies.has(moon.parent_id), "moon parent exists")
		assert_equal(bodies[moon.parent_id].kind, &"planet", "moon parent is a generated planet")
		assert_true(String(moon.id).begins_with(String(system.id) + ":moon:"), "moon id suffix")
		assert_true(moon.designation.begins_with(bodies[moon.parent_id].designation + "-"), "moon name")
	var minor_counts_by_type := {}
	for index in composition.minor_bodies.size():
		var minor = composition.minor_bodies[index]
		var local_type_index: int = minor_counts_by_type.get(minor.subtype, 0)
		assert_equal(minor.id, StringName("%s:minor:%d" % [system.id, index]), "minor id suffix")
		assert_equal(minor.parent_id, primary.id, "minor parent is primary star")
		assert_equal(
			minor.designation,
			naming.minor_body_designation(system_name, minor.subtype, local_type_index),
			"minor name uses ordinal local to its type"
		)
		minor_counts_by_type[minor.subtype] = local_type_index + 1
	_assert_orbits_match_parents(composition, bodies, primary.id)
	_assert_planet_axes_increase(composition)
	_assert_minor_types_cycle(composition.minor_bodies)


func _test_minor_body_ordinals_are_local_to_type() -> void:
	var factory = Factory.new()
	var identity = _identity(101)
	var naming = Naming.new()
	var saw_first := {}
	var saw_second := {}
	for system_index in range(512):
		var system = _system(
			StringName("proc:1:2:-5:6:%d" % system_index),
			Coordinate.new(-5, 6),
			Vector2(float(system_index % 20), float(system_index / 20))
		)
		var composition = factory.create(system, identity)
		var system_name := _system_name(system, identity, naming)
		var local_counts := {}
		for minor in composition.minor_bodies:
			var local_index: int = local_counts.get(minor.subtype, 0)
			assert_equal(
				minor.designation,
				naming.minor_body_designation(system_name, minor.subtype, local_index),
				"minor ordinal increments independently for %s" % minor.subtype
			)
			if local_index == 0:
				assert_true(minor.designation.ends_with("-001"), "first typed minor uses 001")
				saw_first[minor.subtype] = true
			elif local_index == 1:
				assert_true(minor.designation.ends_with("-002"), "second typed minor uses 002")
				saw_second[minor.subtype] = true
			local_counts[minor.subtype] = local_index + 1
	for minor_type in MINOR_TYPES:
		assert_true(saw_first.has(minor_type), "sample covers first %s" % minor_type)
		assert_true(saw_second.has(minor_type), "sample covers second %s" % minor_type)


func _test_full_system_id_distinguishes_same_coordinate_names() -> void:
	var factory = Factory.new()
	var identity = _identity(101)
	var coordinate = Coordinate.new(-3, 2)
	var first = _system(&"proc:1:2:-3:2:1", coordinate, Vector2(4.2, 5.2))
	var second = _system(&"proc:1:2:-3:2:2", coordinate, Vector2(4.2, 5.2))
	var first_name: String = factory.create(first, identity).stars[0].designation
	var second_name: String = factory.create(second, identity).stars[0].designation
	assert_true(first_name != second_name, "full stable system id distinguishes same-position names")


func _identity(seed_value: int):
	return Identity.new(seed_value, Settings.universe_generator_version, Metadata.new(1, 2, 3), Settings)


func _system_name(system, identity, naming) -> String:
	var global_position: Vector2 = (
		Vector2(system.sector.x, system.sector.y) * Settings.universe_sector_size
		+ system.local_position
	)
	return naming.system_designation(
		global_position,
		SeedMixer.mix_text(identity.value, String(system.id) + ":system-ordinal")
	)


func _system(system_id: StringName, sector: Coordinate, local_position: Vector2, z := 20.0):
	return System.new(
		system_id,
		sector,
		local_position,
		&"yellow",
		&"procedural",
		sector,
		10,
		Settings.universe_generator_version,
		z
	)


func _signature(composition) -> Array:
	var result := [composition.system_id]
	for body in composition.stars + composition.planets + composition.moons + composition.minor_bodies:
		result.append([
			body.id,
			body.kind,
			body.designation,
			body.proper_name,
			body.subtype,
			body.parent_id,
			body.properties,
		])
	for orbit in composition.orbits:
		result.append([orbit.orbiter_id, orbit.primary_object_id, orbit.properties])
	return result


func _assert_unique_id(body_id: StringName, ids: Dictionary) -> void:
	assert_true(not ids.has(body_id), "body ids are unique across deterministic sample")
	ids[body_id] = true


func _find_rich_system(factory, identity):
	for index in range(1024):
		var system = _system(
			StringName("proc:1:2:8:-4:%d" % index),
			Coordinate.new(8, -4),
			Vector2(15.4, 20.2)
		)
		var composition = factory.create(system, identity)
		if (
			composition.stars.size() > 1
			and composition.planets.size() > 1
			and composition.moons.size() > 0
			and composition.minor_bodies.size() >= MINOR_TYPES.size()
		):
			return system
	assert_true(false, "deterministic sample must contain a structurally rich system")
	return _system(&"proc:1:2:8:-4:fallback", Coordinate.new(8, -4), Vector2(15.4, 20.2))


func _assert_orbits_match_parents(composition, bodies: Dictionary, primary_id: StringName) -> void:
	var orbit_by_body := {}
	for orbit in composition.orbits:
		assert_true(not orbit_by_body.has(orbit.orbiter_id), "body has only one orbit")
		orbit_by_body[orbit.orbiter_id] = orbit
		assert_true(bodies.has(orbit.orbiter_id), "orbiting body exists")
		assert_true(bodies.has(orbit.primary_object_id), "orbit primary exists")
		assert_equal(
			orbit.primary_object_id,
			bodies[orbit.orbiter_id].parent_id,
			"orbit primary matches body parent"
		)
	assert_true(not orbit_by_body.has(primary_id), "primary star has no orbit")
	assert_equal(orbit_by_body.size(), bodies.size() - 1, "every nonprimary body has an orbit")


func _assert_planet_axes_increase(composition) -> void:
	var previous := 0.0
	for planet in composition.planets:
		var axis: float = _orbit_for(composition.orbits, planet.id).properties["semi_major_axis_au"]
		assert_true(axis > previous, "planet semi-major axes strictly increase")
		previous = axis


func _orbit_for(orbits: Array, body_id: StringName):
	for orbit in orbits:
		if orbit.orbiter_id == body_id:
			return orbit
	return null


func _assert_minor_types_cycle(minor_bodies: Array) -> void:
	for index in range(1, minor_bodies.size()):
		var previous_index: int = MINOR_TYPES.find(minor_bodies[index - 1].subtype)
		assert_equal(
			minor_bodies[index].subtype,
			MINOR_TYPES[(previous_index + 1) % MINOR_TYPES.size()],
			"minor types cycle through supported values"
		)
