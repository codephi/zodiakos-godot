class_name HybridStarFieldView
extends Node3D

const PointLayer = preload("res://scripts/adapters/godot_view/star_point_layer_2d.gd")
const SelectionIndex = preload("res://scripts/application/rendering/system_selection_index.gd")
const GlowBuilder = preload("res://scripts/application/rendering/stellar_glow_batch_builder.gd")
const GlowLayer = preload("res://scripts/adapters/godot_view/stellar_glow_layer.gd")
const LodCoordinator = preload("res://scripts/adapters/godot_view/stellar_lod_coordinator.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var active := {}
var render_origin
var point_layer
var selection_index
var camera_global := Vector2.ZERO
var camera_zoom := 1.0
var viewport_size := Vector2.ONE
var glow_layer
var lod_coordinator


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	selection_index = SelectionIndex.new(settings.universe_sector_size)
	var canvas := CanvasLayer.new()
	canvas.name = "PointCanvas"
	add_child(canvas)
	point_layer = PointLayer.new(settings)
	point_layer.name = "StarPointLayer2D"
	canvas.add_child(point_layer)


func _process(_delta: float) -> void:
	process_glow_pending()


func materialize_sector(sector, origin) -> void:
	render_origin = origin
	var key: String = sector.coordinate.key()
	if active.has(key):
		return
	active[key] = {"coordinate": sector.coordinate, "sector": sector}
	selection_index.add_sector(sector)
	if lod_coordinator != null:
		lod_coordinator.notify_data_changed(all_system_entries())
	_refresh_points()


func remove_sector(coordinate) -> void:
	active.erase(coordinate.key())
	selection_index.remove_sector(coordinate)
	if lod_coordinator != null:
		lod_coordinator.notify_data_changed(all_system_entries())
	_refresh_points()


func rebase(origin) -> void:
	render_origin = origin
	if glow_layer != null:
		glow_layer.position = Vector3(
			-float(origin.x) * settings.universe_sector_size,
			0.0,
			-float(origin.y) * settings.universe_sector_size
		)


func update_camera(global_position: Vector2, zoom: float, next_viewport_size: Vector2) -> void:
	camera_global = global_position
	camera_zoom = zoom
	viewport_size = next_viewport_size
	if lod_coordinator != null:
		lod_coordinator.update_camera(global_position, zoom, next_viewport_size)
	_refresh_points()


func configure_glow(profile_service) -> void:
	if lod_coordinator != null:
		return
	glow_layer = GlowLayer.new(settings)
	glow_layer.name = "StellarGlowLayer"
	add_child(glow_layer)
	lod_coordinator = LodCoordinator.new(
		settings,
		GlowBuilder.new(profile_service, settings),
		glow_layer
	)
	lod_coordinator.notify_data_changed(all_system_entries())
	lod_coordinator.update_camera(camera_global, camera_zoom, viewport_size)


func process_glow_pending(limit := -1) -> int:
	if lod_coordinator == null:
		return 0
	var processed: int = lod_coordinator.process_pending(limit)
	_refresh_points()
	return processed


func pick_screen(screen_position: Vector2):
	if viewport_size.y <= 0.0:
		return null
	var world: Vector2 = camera_global + (screen_position - viewport_size * 0.5) * camera_zoom / viewport_size.y
	var radius: float = settings.stellar_selection_radius_pixels * camera_zoom / viewport_size.y
	return selection_index.pick(world, radius)


func renderer_metrics() -> Dictionary:
	if lod_coordinator == null:
		return {"mode": &"points_2d", "glow_instances": 0, "pending": 0}
	return lod_coordinator.metrics()


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
	var entries := all_system_entries()
	point_layer.update_snapshot(
		entries,
		camera_global,
		camera_zoom,
		viewport_size,
		{} if lod_coordinator == null else lod_coordinator.suppressed_ids
	)
