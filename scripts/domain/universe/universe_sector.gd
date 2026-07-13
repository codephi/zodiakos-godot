class_name UniverseSector
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const StellarSystemDefinitionType = preload(
	"res://scripts/domain/universe/stellar_system_definition.gd"
)
const DefaultSettings = preload("res://config/game_settings.tres")

var coordinate: SectorCoordinateType:
	get:
		return _coordinate.offset(0, 0)
var systems: Array[StellarSystemDefinitionType]:
	get:
		return _systems.duplicate()
var generator_version: int:
	get:
		return _generator_version

var _coordinate: SectorCoordinateType
var _systems: Array[StellarSystemDefinitionType] = []
var _generator_version: int


func _init(
	sector_coordinate: SectorCoordinateType,
	generated_systems: Array,
	version: int = DefaultSettings.universe_generator_version
) -> void:
	_coordinate = sector_coordinate.offset(0, 0)
	_systems.assign(generated_systems)
	_systems.sort_custom(func(left, right): return String(left.id) < String(right.id))
	_generator_version = version


func system_count() -> int:
	return _systems.size()
