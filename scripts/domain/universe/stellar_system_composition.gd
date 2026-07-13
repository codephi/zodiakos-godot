class_name StellarSystemComposition
extends RefCounted

const SystemBodyDefinitionType = preload(
	"res://scripts/domain/universe/system_body_definition.gd"
)
const OrbitDefinitionType = preload("res://scripts/domain/universe/orbit_definition.gd")

var system_id: StringName:
	get:
		return _system_id
var stars: Array[SystemBodyDefinitionType]:
	get:
		return _stars.duplicate()
var planets: Array[SystemBodyDefinitionType]:
	get:
		return _planets.duplicate()
var moons: Array[SystemBodyDefinitionType]:
	get:
		return _moons.duplicate()
var minor_bodies: Array[SystemBodyDefinitionType]:
	get:
		return _minor_bodies.duplicate()
var orbits: Array[OrbitDefinitionType]:
	get:
		return _orbits.duplicate()

var _system_id: StringName
var _stars: Array[SystemBodyDefinitionType] = []
var _planets: Array[SystemBodyDefinitionType] = []
var _moons: Array[SystemBodyDefinitionType] = []
var _minor_bodies: Array[SystemBodyDefinitionType] = []
var _orbits: Array[OrbitDefinitionType] = []


func _init(
	composition_system_id: StringName,
	stellar_bodies: Array,
	planetary_bodies: Array,
	lunar_bodies: Array,
	small_bodies: Array,
	system_orbits: Array
) -> void:
	assert(not composition_system_id.is_empty(), "Composition system id must not be empty")
	var body_ids := {}
	_validate_body_array(stellar_bodies, &"star", body_ids)
	_validate_body_array(planetary_bodies, &"planet", body_ids)
	_validate_body_array(lunar_bodies, &"moon", body_ids)
	_validate_body_array(small_bodies, &"minor_body", body_ids)
	_validate_primary_and_secondary_stars(stellar_bodies)
	_validate_orbits(system_orbits)

	_system_id = composition_system_id
	_stars.assign(stellar_bodies)
	_planets.assign(planetary_bodies)
	_moons.assign(lunar_bodies)
	_minor_bodies.assign(small_bodies)
	_orbits.assign(system_orbits)


func _validate_body_array(bodies: Array, expected_kind: StringName, ids: Dictionary) -> void:
	for body in bodies:
		assert(body is SystemBodyDefinitionType, "Composition bodies must be definitions")
		assert(body.kind == expected_kind, "Composition body is in the wrong category")
		assert(not ids.has(body.id), "Composition body ids must be unique")
		ids[body.id] = true


func _validate_primary_and_secondary_stars(stellar_bodies: Array) -> void:
	var primary_count := 0
	var primary_id := StringName()
	for star in stellar_bodies:
		if star.parent_id.is_empty():
			primary_count += 1
			primary_id = star.id
	assert(primary_count == 1, "A composition requires exactly one primary star")
	for star in stellar_bodies:
		if not star.parent_id.is_empty():
			assert(
				star.parent_id == primary_id,
				"Every secondary star must point to the primary star"
			)


func _validate_orbits(system_orbits: Array) -> void:
	var orbiters := {}
	for orbit in system_orbits:
		assert(orbit is OrbitDefinitionType, "Composition orbits must be definitions")
		assert(not orbiters.has(orbit.orbiter_id), "An orbiter can have only one orbit")
		orbiters[orbit.orbiter_id] = true
