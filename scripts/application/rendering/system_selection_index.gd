class_name SystemSelectionIndex
extends RefCounted

var sector_size: float
var sectors := {}


func _init(configured_sector_size: float) -> void:
	sector_size = configured_sector_size


func add_sector(sector) -> void:
	sectors[sector.coordinate.key()] = sector


func remove_sector(coordinate) -> void:
	sectors.erase(coordinate.key())


func pick(world_position: Vector2, world_radius: float):
	var first_x := floori((world_position.x - world_radius) / sector_size)
	var last_x := floori((world_position.x + world_radius) / sector_size)
	var first_y := floori((world_position.y - world_radius) / sector_size)
	var last_y := floori((world_position.y + world_radius) / sector_size)
	var closest = null
	var closest_distance := INF
	for x in range(first_x, last_x + 1):
		for y in range(first_y, last_y + 1):
			var sector = sectors.get("%d:%d" % [x, y])
			if sector == null:
				continue
			for system in sector.systems:
				var system_global: Vector2 = Vector2(x, y) * sector_size + system.local_position
				var distance: float = system_global.distance_to(world_position)
				if distance > world_radius:
					continue
				if distance < closest_distance or (
					is_equal_approx(distance, closest_distance)
					and (closest == null or String(system.id) < String(closest.id))
				):
					closest = system
					closest_distance = distance
	return closest
