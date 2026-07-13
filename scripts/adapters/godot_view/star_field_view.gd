class_name StarFieldView
extends Node3D

const StarVisualType = preload("res://scripts/visuals/star_visual.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")

var active := {}
var render_origin


func materialize_sector(sector, origin) -> void:
	render_origin = origin
	var coordinate = sector.coordinate
	var key: String = coordinate.key()
	if active.has(key):
		return

	var container := Node3D.new()
	container.name = "Sector_%d_%d" % [coordinate.x, coordinate.y]
	add_child(container)
	for definition in sector.stars:
		var visual := StarVisualType.new()
		visual.name = String(definition.id)
		visual.set_meta("star_id", definition.id)
		visual.position = Vector3(
			definition.local_position.x,
			0.0,
			definition.local_position.y
		)
		container.add_child(visual)
		var visual_type: StringName = definition.visual_type
		if not Config.VISUAL_TYPES.has(visual_type):
			visual_type = &"yellow"
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


func star_count() -> int:
	var total := 0
	for entry in active.values():
		total += entry.sector.stars.size()
	return total


func sector_signature(coordinate) -> Array:
	var result := []
	for star in active[coordinate.key()].sector.stars:
		result.append(String(star.id))
	return result


func _reposition(entry: Dictionary) -> void:
	var coordinate = entry.coordinate
	var sector_delta_x: int = coordinate.x - render_origin.x
	var sector_delta_y: int = coordinate.y - render_origin.y
	entry.node.position = Vector3(
		float(sector_delta_x) * Config.SECTOR_SIZE,
		0.0,
		float(sector_delta_y) * Config.SECTOR_SIZE
	)
