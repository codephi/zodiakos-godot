class_name SystemAnchor
extends RefCounted

var id: StringName:
	get:
		return _id
var canonical_designation: String:
	get:
		return _canonical_designation
var proper_name: String:
	get:
		return _proper_name
var galactocentric_position: Vector3:
	get:
		return _galactocentric_position

var _id: StringName
var _canonical_designation: String
var _proper_name: String
var _galactocentric_position: Vector3


func _init(
	anchor_id: StringName,
	designation: String,
	name: String,
	position: Vector3
) -> void:
	_id = anchor_id
	_canonical_designation = designation
	_proper_name = name
	_galactocentric_position = position


func map_position() -> Vector2:
	return Vector2(_galactocentric_position.x, _galactocentric_position.y)
