class_name OrbitDefinition
extends RefCounted

var orbiter_id: StringName:
	get:
		return _orbiter_id
var primary_object_id: StringName:
	get:
		return _primary_object_id
var properties: Dictionary:
	get:
		return _properties.duplicate(true)

var _orbiter_id: StringName
var _primary_object_id: StringName
var _properties: Dictionary


func _init(
	orbiting_object_id: StringName,
	orbit_primary_object_id: StringName,
	scientific_properties: Dictionary
) -> void:
	assert(not orbiting_object_id.is_empty(), "Orbiting object id must not be empty")
	assert(not orbit_primary_object_id.is_empty(), "Orbit primary object id must not be empty")
	assert(
		orbiting_object_id != orbit_primary_object_id,
		"An object cannot orbit itself"
	)
	for property_key in scientific_properties:
		assert(
			_is_scientific_property(StringName(property_key)),
			"Unsupported orbit property: %s" % property_key
		)
	_orbiter_id = orbiting_object_id
	_primary_object_id = orbit_primary_object_id
	_properties = scientific_properties.duplicate(true)


func _is_scientific_property(value: StringName) -> bool:
	match value:
		&"semi_major_axis_au", &"eccentricity", &"inclination_deg":
			return true
		&"orbital_period_days", &"longitude_ascending_node_deg":
			return true
		&"argument_periapsis_deg", &"mean_anomaly_deg", &"elements_epoch":
			return true
	return false
