class_name SystemBodyDefinition
extends RefCounted

var id: StringName:
	get:
		return _id
var kind: StringName:
	get:
		return _kind
var designation: String:
	get:
		return _designation
var proper_name: String:
	get:
		return _proper_name
var subtype: StringName:
	get:
		return _subtype
var parent_id: StringName:
	get:
		return _parent_id
var properties: Dictionary:
	get:
		return _properties.duplicate(true)

var _id: StringName
var _kind: StringName
var _designation: String
var _proper_name: String
var _subtype: StringName
var _parent_id: StringName
var _properties: Dictionary


func _init(
	body_id: StringName,
	body_kind: StringName,
	body_designation: String,
	body_proper_name: String,
	body_subtype: StringName,
	body_parent_id: StringName,
	body_properties: Dictionary
) -> void:
	assert(not body_id.is_empty(), "System body id must not be empty")
	assert(_is_supported_kind(body_kind), "Unsupported system body kind: %s" % body_kind)
	assert(body_parent_id != body_id, "A system body cannot parent itself")
	assert(
		body_kind == &"star" or not body_parent_id.is_empty(),
		"Planets, moons and minor bodies require a parent"
	)
	_id = body_id
	_kind = body_kind
	_designation = body_designation
	_proper_name = body_proper_name
	_subtype = body_subtype
	_parent_id = body_parent_id
	_properties = body_properties.duplicate(true)


func _is_supported_kind(value: StringName) -> bool:
	match value:
		&"star", &"planet", &"moon", &"minor_body":
			return true
	return false
