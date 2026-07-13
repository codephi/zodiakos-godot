class_name ProceduralSystemFactory
extends RefCounted

const Body = preload("res://scripts/domain/universe/system_body_definition.gd")
const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Naming = preload("res://scripts/domain/universe/dynamic_naming_service.gd")
const Orbit = preload("res://scripts/domain/universe/orbit_definition.gd")
const StellarSystem = preload("res://scripts/domain/universe/stellar_system_definition.gd")

const MINOR_TYPE_COUNT := 6

var _naming


func _init(naming_service = null) -> void:
	_naming = Naming.new() if naming_service == null else naming_service


func create(system: StellarSystem, universe_identity: Identity) -> Composition:
	assert(system != null, "Procedural system factory requires a system")
	assert(not system.id.is_empty(), "Procedural system id must not be empty")
	assert(system.source == &"procedural", "Procedural factory accepts procedural systems only")
	assert(universe_identity != null, "Procedural system factory requires universe identity")
	assert(universe_identity.value > 0, "Universe identity must be positive")
	var snapshot: Dictionary = universe_identity.configuration_snapshot()

	var global_position: Vector2 = (
		Vector2(system.sector.x, system.sector.y) * snapshot.universe_sector_size
		+ system.local_position
	)
	var ordinal := Mixer.mix_text(
		universe_identity.value,
		String(system.id) + ":system-ordinal"
	)
	var system_designation: String = _naming.system_designation(global_position, ordinal)
	var stars := []
	var planets := []
	var moons := []
	var minor_bodies := []
	var orbits := []
	_create_stars(system, universe_identity, snapshot, system_designation, stars, orbits)
	var primary_id: StringName = stars[0].id
	_create_planets(
		system,
		universe_identity,
		snapshot,
		system_designation,
		primary_id,
		planets,
		moons,
		orbits
	)
	_create_minor_bodies(
		system,
		universe_identity,
		snapshot,
		system_designation,
		primary_id,
		planets.size(),
		minor_bodies,
		orbits
	)
	return Composition.new(system.id, stars, planets, moons, minor_bodies, orbits)


func _create_stars(
	system: StellarSystem,
	identity: Identity,
	snapshot: Dictionary,
	system_designation: String,
	stars: Array,
	orbits: Array
) -> void:
	var star_count := _rng(system.id, identity, ":star-count").randi_range(
		snapshot.system_min_stars,
		snapshot.system_max_stars
	)
	var primary_id := StringName("%s:star:0" % system.id)
	for index in star_count:
		var star_id := StringName("%s:star:%d" % [system.id, index])
		var parent_id := StringName() if index == 0 else primary_id
		stars.append(
			Body.new(
				star_id,
				&"star",
				_naming.star_designation(system_designation, index),
				"",
				_weighted_type(
					_rng(system.id, identity, ":star-type:%d" % index),
					snapshot.universe_visual_types,
					snapshot.universe_visual_type_weights
				),
				parent_id,
				{}
			)
		)
		if index > 0:
			orbits.append(
				Orbit.new(
					star_id,
					primary_id,
					{
						"semi_major_axis_au": float(index)
						+ _rng(system.id, identity, ":star-axis:%d" % index).randf()
					}
				)
			)


func _create_planets(
	system: StellarSystem,
	identity: Identity,
	snapshot: Dictionary,
	system_designation: String,
	primary_id: StringName,
	planets: Array,
	moons: Array,
	orbits: Array
) -> void:
	var planet_count := _rng(system.id, identity, ":planet-count").randi_range(
		0,
		snapshot.system_max_planets
	)
	var semi_major_axis_au := 0.0
	for planet_index in planet_count:
		var planet_id := StringName("%s:planet:%d" % [system.id, planet_index])
		var designation: String = _naming.planet_designation(system_designation, planet_index)
		semi_major_axis_au += 1.0 + _rng(
			system.id,
			identity,
			":planet-axis:%d" % planet_index
		).randf()
		planets.append(
			Body.new(
				planet_id,
				&"planet",
				designation,
				"",
				_weighted_type(
					_rng(system.id, identity, ":planet-type:%d" % planet_index),
					snapshot.system_planet_types,
					snapshot.system_planet_type_weights
				),
				primary_id,
				{}
			)
		)
		orbits.append(
			Orbit.new(
				planet_id,
				primary_id,
				{"semi_major_axis_au": semi_major_axis_au}
			)
		)
		_create_moons(
			system,
			identity,
			snapshot,
			planet_index,
			planet_id,
			designation,
			moons,
			orbits
		)


func _create_moons(
	system: StellarSystem,
	identity: Identity,
	snapshot: Dictionary,
	planet_index: int,
	planet_id: StringName,
	planet_designation: String,
	moons: Array,
	orbits: Array
) -> void:
	var moon_count := _rng(
		system.id,
		identity,
		":moon-count:%d" % planet_index
	).randi_range(0, snapshot.system_max_moons_per_planet)
	for moon_index in moon_count:
		var moon_id := StringName(
			"%s:moon:%d:%d" % [system.id, planet_index, moon_index]
		)
		moons.append(
			Body.new(
				moon_id,
				&"moon",
				_naming.moon_designation(planet_designation, moon_index),
				"",
				&"moon",
				planet_id,
				{}
			)
		)
		orbits.append(
			Orbit.new(
				moon_id,
				planet_id,
				{
					"semi_major_axis_au": (
						float(moon_index + 1)
						+ _rng(
							system.id,
							identity,
							":moon-axis:%d:%d" % [planet_index, moon_index]
						).randf()
					) / 1000.0
				}
			)
		)


func _create_minor_bodies(
	system: StellarSystem,
	identity: Identity,
	snapshot: Dictionary,
	system_designation: String,
	primary_id: StringName,
	planet_count: int,
	minor_bodies: Array,
	orbits: Array
) -> void:
	var minor_count := _rng(system.id, identity, ":minor-count").randi_range(
		0,
		snapshot.system_max_minor_bodies
	)
	var first_type := _rng(system.id, identity, ":minor-type-offset").randi_range(
		0,
		MINOR_TYPE_COUNT - 1
	)
	var type_counts := {}
	for index in minor_count:
		var minor_id := StringName("%s:minor:%d" % [system.id, index])
		var minor_type := _minor_type_at(first_type + index)
		var local_type_index: int = type_counts.get(minor_type, 0)
		minor_bodies.append(
			Body.new(
				minor_id,
				&"minor_body",
				_naming.minor_body_designation(
					system_designation,
					minor_type,
					local_type_index
				),
				"",
				minor_type,
				primary_id,
				{}
			)
		)
		type_counts[minor_type] = local_type_index + 1
		orbits.append(
			Orbit.new(
				minor_id,
				primary_id,
				{
					"semi_major_axis_au": float(planet_count + index + 1)
					+ _rng(system.id, identity, ":minor-axis:%d" % index).randf()
				}
			)
		)


func _rng(system_id: StringName, identity: Identity, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix_text(identity.value, String(system_id) + tag)
	return rng


func _weighted_type(
	rng: RandomNumberGenerator,
	types: Array[StringName],
	weights: Array[int]
) -> StringName:
	var total_weight := 0
	for weight in weights:
		total_weight += weight
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative_weight := 0
	for index in types.size():
		cumulative_weight += weights[index]
		if roll < cumulative_weight:
			return types[index]
	return types.back()


func _minor_type_at(index: int) -> StringName:
	match posmod(index, MINOR_TYPE_COUNT):
		0:
			return &"asteroid"
		1:
			return &"comet"
		2:
			return &"dwarf_planet"
		3:
			return &"trans_neptunian"
		4:
			return &"meteoroid"
		_:
			return &"interstellar_object"
