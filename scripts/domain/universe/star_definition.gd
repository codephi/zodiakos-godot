class_name StarDefinition
extends RefCounted

const GeneratorConfig = preload("res://scripts/domain/universe/universe_generator_config.gd")
const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")

var id: StringName:
	get:
		return _id
var sector: SectorCoordinateType:
	get:
		return _sector.offset(0, 0)
var local_position: Vector2:
	get:
		return _local_position
var visual_type: StringName:
	get:
		return _visual_type
var source: StringName:
	get:
		return _source
var owner_sector: SectorCoordinateType:
	get:
		return _owner_sector.offset(0, 0)
var priority: int:
	get:
		return _priority
var generator_version: int:
	get:
		return GeneratorConfig.GENERATOR_VERSION

var _id: StringName
var _sector: SectorCoordinateType
var _local_position: Vector2
var _visual_type: StringName
var _source: StringName
var _owner_sector: SectorCoordinateType
var _priority: int


func _init(
	star_id: StringName,
	star_sector: SectorCoordinateType,
	position: Vector2,
	type: StringName,
	star_source: StringName,
	owner: SectorCoordinateType,
	star_priority: int
) -> void:
	_id = star_id
	_sector = star_sector.offset(0, 0)
	_local_position = position
	_visual_type = type
	_source = star_source
	_owner_sector = owner.offset(0, 0)
	_priority = star_priority
