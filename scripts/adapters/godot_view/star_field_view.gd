class_name StarFieldView
extends Node3D

const StarVisualType = preload("res://scripts/visuals/star_visual.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var active := {}
var render_origin


func _init(configuration = DefaultSettings) -> void:
	settings = configuration


func materialize_sector(sector, origin) -> void:
	render_origin = origin
	var coordinate = sector.coordinate
	var key: String = coordinate.key()
	if active.has(key):
		return

	var container := Node3D.new()
	container.name = "Sector_%d_%d" % [coordinate.x, coordinate.y]
	add_child(container)
	for definition in sector.systems:
		var visual := StarVisualType.new(settings)
		visual.name = String(definition.id)
		visual.set_meta("system_id", definition.id)
		visual.position = Vector3(
			definition.local_position.x,
			0.0,
			definition.local_position.y
		)
		container.add_child(visual)
		var visual_type: StringName = definition.visual_type
		if not settings.universe_visual_types.has(visual_type):
			visual_type = settings.universe_visual_types[0]
		visual.configure(visual_type)

	active[key] = {
		"coordinate": coordinate,
		"sector": sector,
		"node": container,
	}
	_reposition(active[key])


func remove_sector(coordinate) -> void:
	var key: String = coordinate.key()
	var entry = active.get(key)
	if entry == null:
		return
	entry.node.queue_free()
	active.erase(key)


func rebase(origin) -> void:
	render_origin = origin
	for entry in active.values():
		_reposition(entry)


func has_sector(coordinate) -> bool:
	return active.has(coordinate.key())


func active_keys() -> Dictionary:
	var result := {}
	for key in active:
		result[key] = true
	return result


func active_coordinates() -> Array:
	var result := []
	for entry in active.values():
		result.append(entry.coordinate)
	return result


func active_sector_count() -> int:
	return active.size()


func system_count() -> int:
	var total := 0
	for entry in active.values():
		total += entry.sector.system_count()
	return total


func sector_signature(coordinate) -> Array:
	var result := []
	for system in active[coordinate.key()].sector.systems:
		result.append(String(system.id))
	return result


func _reposition(entry: Dictionary) -> void:
	var coordinate = entry.coordinate
	var sector_delta_x: int = coordinate.x - render_origin.x
	var sector_delta_y: int = coordinate.y - render_origin.y
	entry.node.position = Vector3(
		float(sector_delta_x) * settings.universe_sector_size,
		0.0,
		float(sector_delta_y) * settings.universe_sector_size
	)
