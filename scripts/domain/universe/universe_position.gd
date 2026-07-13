class_name UniversePosition
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Scale = preload("res://scripts/domain/universe/universe_scale.gd")
const SECTOR_SIZE := Scale.SECTOR_SIZE

var sector
var local: Vector2


func _init(initial_sector = null, initial_local := Vector2.ZERO) -> void:
	sector = initial_sector if initial_sector != null else SectorCoordinateType.new()
	local = initial_local
	_normalize()


func moved(delta: Vector2):
	return get_script().new(sector.offset(0, 0), local + delta)


func relative_to(origin) -> Vector2:
	return Vector2(float(sector.x - origin.x), float(sector.y - origin.y)) * SECTOR_SIZE + local


func _normalize() -> void:
	var delta_x := int(floor(local.x / SECTOR_SIZE))
	var delta_y := int(floor(local.y / SECTOR_SIZE))
	sector = sector.offset(delta_x, delta_y)
	local -= Vector2(delta_x, delta_y) * SECTOR_SIZE
