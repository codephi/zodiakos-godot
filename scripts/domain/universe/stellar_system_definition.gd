class_name StellarSystemDefinition
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

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
		return _generator_version
var galactocentric_z_pc: float:
	get:
		return _galactocentric_z_pc

var _id: StringName
var _sector: SectorCoordinateType
var _local_position: Vector2
var _visual_type: StringName
var _source: StringName
var _owner_sector: SectorCoordinateType
var _priority: int
var _generator_version: int
var _galactocentric_z_pc: float


func _init(
	system_id: StringName,
	system_sector: SectorCoordinateType,
	position: Vector2,
	type: StringName,
	system_source: StringName,
	owner: SectorCoordinateType,
	system_priority: int,
	version: int = DefaultSettings.universe_generator_version,
	z_pc: float = 0.0
) -> void:
	_id = system_id
	_sector = system_sector.offset(0, 0)
	_local_position = position
	_visual_type = type
	_source = system_source
	_owner_sector = owner.offset(0, 0)
	_priority = system_priority
	_generator_version = version
	_galactocentric_z_pc = z_pc
