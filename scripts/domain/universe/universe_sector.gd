class_name UniverseSector
extends RefCounted

const GeneratorConfig = preload("res://scripts/domain/universe/universe_generator_config.gd")
const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")

var coordinate: SectorCoordinateType:
	get:
		return _coordinate.offset(0, 0)
var stars: Array:
	get:
		return _stars.duplicate()
var generator_version: int:
	get:
		return GeneratorConfig.GENERATOR_VERSION

var _coordinate: SectorCoordinateType
var _stars: Array


func _init(sector_coordinate: SectorCoordinateType, generated_stars: Array) -> void:
	_coordinate = sector_coordinate.offset(0, 0)
	_stars = generated_stars.duplicate()
	_stars.sort_custom(func(left, right): return String(left.id) < String(right.id))
