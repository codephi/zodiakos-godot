class_name UniversePosition
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var sector
var local: Vector2
var sector_size: float


func _init(
	initial_sector = null,
	initial_local := Vector2.ZERO,
	configured_sector_size: float = DefaultSettings.universe_sector_size
) -> void:
	sector = initial_sector if initial_sector != null else SectorCoordinateType.new()
	local = initial_local
	sector_size = configured_sector_size
	_normalize()


func moved(delta: Vector2):
	return get_script().new(sector.offset(0, 0), local + delta, sector_size)


func relative_to(origin) -> Vector2:
	return (
		Vector2(float(sector.x - origin.x), float(sector.y - origin.y))
		* sector_size
		+ local
	)


func _normalize() -> void:
	var delta_x := int(floor(local.x / sector_size))
	var delta_y := int(floor(local.y / sector_size))
	sector = sector.offset(delta_x, delta_y)
	local -= Vector2(delta_x, delta_y) * sector_size
