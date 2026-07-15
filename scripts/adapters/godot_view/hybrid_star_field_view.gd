class_name HybridStarFieldView
extends Node3D

const PointLayer = preload("res://scripts/adapters/godot_view/star_point_layer_2d.gd")
const SelectionIndex = preload("res://scripts/application/rendering/system_selection_index.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var active := {}
var render_origin
var point_layer
var selection_index
var camera_global := Vector2.ZERO
var camera_zoom := 1.0
var viewport_size := Vector2.ONE


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	selection_index = SelectionIndex.new(settings.universe_sector_size)
	var canvas := CanvasLayer.new()
	canvas.name = "PointCanvas"
	add_child(canvas)
	point_layer = PointLayer.new(settings)
	point_layer.name = "StarPointLayer2D"
	canvas.add_child(point_layer)


func materialize_sector(sector, origin) -> void:
	render_origin = origin
	var key: String = sector.coordinate.key()
	if active.has(key):
		return
	active[key] = {"coordinate": sector.coordinate, "sector": sector}
	selection_index.add_sector(sector)
	_refresh_points()


func remove_sector(coordinate) -> void:
	active.erase(coordinate.key())
	selection_index.remove_sector(coordinate)
	_refresh_points()


func rebase(origin) -> void:
	render_origin = origin


func update_camera(global_position: Vector2, zoom: float, next_viewport_size: Vector2) -> void:
	camera_global = global_position
	camera_zoom = zoom
	viewport_size = next_viewport_size
	_refresh_points()


func active_keys() -> Dictionary:
	var result := {}
	for key in active:
		result[key] = true
	return result


func active_coordinates() -> Array:
	return active.values().map(func(entry): return entry.coordinate)


func active_sector_count() -> int:
	return active.size()


func system_count() -> int:
	var total := 0
	for entry in active.values():
		total += entry.sector.system_count()
	return total


func sector_signature(coordinate) -> Array:
	return active[coordinate.key()].sector.systems.map(func(system): return String(system.id))


func all_system_entries() -> Array:
	var entries: Array = []
	for entry in active.values():
		for system in entry.sector.systems:
			entries.append({
				"id": system.id,
				"definition": system,
				"visual_type": system.visual_type,
				"global_position": Vector2(system.sector.x, system.sector.y)
					* settings.universe_sector_size + system.local_position,
			})
	return entries


func _refresh_points() -> void:
	point_layer.update_snapshot(all_system_entries(), camera_global, camera_zoom, viewport_size)
