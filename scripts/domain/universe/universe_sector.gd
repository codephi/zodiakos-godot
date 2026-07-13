class_name UniverseSector
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var coordinate: SectorCoordinateType:
	get:
		return _coordinate.offset(0, 0)
var stars: Array:
	get:
		return _stars.duplicate()
var generator_version: int:
	get:
		return _generator_version

var _coordinate: SectorCoordinateType
var _stars: Array
var _generator_version: int


func _init(
	sector_coordinate: SectorCoordinateType,
	generated_stars: Array,
	version: int = DefaultSettings.universe_generator_version
) -> void:
	_coordinate = sector_coordinate.offset(0, 0)
	_stars = generated_stars.duplicate()
	_stars.sort_custom(func(left, right): return String(left.id) < String(right.id))
	_generator_version = version
