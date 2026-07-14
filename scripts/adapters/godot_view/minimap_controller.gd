class_name MinimapController
extends Node

signal snapshot_changed(snapshot: Dictionary)
signal navigation_requested(target_global: Vector2)

const ProjectionScript = preload("res://scripts/application/minimap/minimap_projection.gd")
const LodPolicy = preload("res://scripts/application/minimap/minimap_lod_policy.gd")
const SectorCoordinateScript = preload("res://scripts/domain/universe/sector_coordinate.gd")
const SectorRingIterator = preload("res://scripts/application/streaming/sector_ring_iterator.gd")

var settings
var query_service
var projection
var lod_policy
var generation_id := 0
var lod: StringName = &"exact"
var follow_main_camera := true
var main_camera_global := Vector2.ZERO
var visible_rect := Rect2()
var preload_rect := Rect2()
var loading := false
var error_count := 0

var _sector_iterator
var _first_sector := Vector2i.ZERO
var _last_sector := Vector2i.ZERO
var _cell_index := 0
var _cell_total := 0
var _cell_resolution := 0
var _systems: Array = []
var _cells: Array = []
var _catalog_systems: Array = []
var _last_snapshot: Dictionary = {}


func _init(configuration) -> void:
	settings = configuration
	lod_policy = LodPolicy.new(settings)


func configure(
	service,
	center_global: Vector2,
	camera_view_height: float,
	aspect_ratio: float,
	preload_view_height: float
) -> void:
	query_service = service
	main_camera_global = center_global
	var requested_height: float = maxf(
		camera_view_height * settings.minimap_initial_view_scale,
		preload_view_height * 1.1
	)
	requested_height = clampf(
		requested_height,
		settings.minimap_min_view_height,
		settings.minimap_max_view_height
	)
	projection = ProjectionScript.new(center_global, requested_height, aspect_ratio)
	refresh_now()


func _process(_delta: float) -> void:
	if loading:
		process_pending()


func refresh_now() -> void:
	if query_service == null or projection == null:
		return
	generation_id += 1
	_systems.clear()
	_cells.clear()
	_catalog_systems.clear()
	error_count = 0
	_cell_index = 0
	_cell_total = 0
	_sector_iterator = null

	var sector_range := _calculate_sector_range()
	_first_sector = sector_range.first
	_last_sector = sector_range.last
	var sector_count: int = sector_range.count
	lod = lod_policy.select(sector_count)
	if lod == &"exact":
		var sector_size: float = settings.universe_sector_size
		var center := SectorCoordinateScript.new(
			floori(projection.center_global.x / sector_size),
			floori(projection.center_global.y / sector_size)
		)
		var radii := Vector2i(
			maxi(absi(center.x - _first_sector.x), absi(_last_sector.x - center.x)),
			maxi(absi(center.y - _first_sector.y), absi(_last_sector.y - center.y))
		)
		_sector_iterator = SectorRingIterator.new(center, radii)
	else:
		_cell_resolution = (
			settings.minimap_cluster_grid_resolution
			if lod == &"cluster"
			else settings.minimap_density_grid_resolution
		)
		_cell_total = _cell_resolution * _cell_resolution
		_catalog_systems = query_service.catalog_points(projection.bounds())
	loading = sector_count > 0 if lod == &"exact" else _cell_total > 0
	_publish_snapshot(sector_count)


func process_pending(limit := -1, requested_generation := -1) -> int:
	if requested_generation >= 0 and requested_generation != generation_id:
		return 0
	if not loading:
		return 0
	var budget: int = limit
	if budget < 0:
		budget = (
			settings.minimap_query_sectors_per_frame
			if lod == &"exact"
			else settings.minimap_density_cells_per_frame
		)
	var processed := 0
	if lod == &"exact":
		processed = _process_exact(budget)
	else:
		processed = _process_cells(budget)
	_publish_snapshot(_sector_count())
	return processed


func set_main_camera_state(
	camera_global: Vector2,
	current_visible_rect: Rect2,
	current_preload_rect: Rect2,
	aspect_ratio: float
) -> void:
	main_camera_global = camera_global
	visible_rect = current_visible_rect
	preload_rect = current_preload_rect
	if follow_main_camera and projection != null:
		var changed: bool = not projection.center_global.is_equal_approx(camera_global)
		changed = changed or not is_equal_approx(projection.aspect_ratio, aspect_ratio)
		projection.center_global = camera_global
		projection.aspect_ratio = maxf(aspect_ratio, 0.000001)
		if changed:
			refresh_now()
			return
	_publish_snapshot(_sector_count())


func pan_pixels(delta_pixels: Vector2, panel_size: Vector2) -> void:
	if projection == null or panel_size.y <= 0.0:
		return
	follow_main_camera = false
	var world_per_pixel: float = projection.view_height / panel_size.y
	projection.center_global -= delta_pixels * world_per_pixel
	refresh_now()


func zoom_steps_at(steps: int, cursor_pixel: Vector2, drawing_rect: Rect2) -> void:
	if projection == null or steps == 0:
		return
	projection = projection.zoom_at(
		steps,
		cursor_pixel,
		drawing_rect,
		settings.minimap_zoom_factor,
		settings.minimap_min_view_height,
		settings.minimap_max_view_height
	)
	refresh_now()


func center_on_main_camera() -> void:
	if projection == null:
		return
	follow_main_camera = true
	projection.center_global = main_camera_global
	refresh_now()


func navigate_to(target_global: Vector2) -> void:
	if projection == null:
		return
	follow_main_camera = true
	main_camera_global = target_global
	projection.center_global = target_global
	refresh_now()
	navigation_requested.emit(target_global)


func snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func _process_exact(budget: int) -> int:
	var processed := 0
	while processed < budget and _sector_iterator != null:
		var coordinate = _sector_iterator.next_coordinate()
		if coordinate == null:
			loading = false
			break
		if not _contains_sector(coordinate.x, coordinate.y):
			continue
		_systems.append_array(query_service.exact_points(coordinate))
		processed += 1
	if _sector_iterator != null and _sector_iterator.is_exhausted():
		loading = false
	return processed


func _process_cells(budget: int) -> int:
	var processed := 0
	while processed < budget and _cell_index < _cell_total:
		_cells.append(query_service.sample_cell(
			projection.bounds(),
			_cell_resolution,
			_cell_index,
			lod
		))
		_cell_index += 1
		processed += 1
	if _cell_index >= _cell_total:
		loading = false
	return processed


func _calculate_sector_range() -> Dictionary:
	var bounds: Rect2 = projection.bounds()
	var size: float = settings.universe_sector_size
	var first := Vector2i(
		floori(bounds.position.x / size),
		floori(bounds.position.y / size)
	)
	var last := Vector2i(
		ceili(bounds.end.x / size) - 1,
		ceili(bounds.end.y / size) - 1
	)
	var count := maxi(last.x - first.x + 1, 0) * maxi(last.y - first.y + 1, 0)
	return {"first": first, "last": last, "count": count}


func _sector_count() -> int:
	return (
		maxi(_last_sector.x - _first_sector.x + 1, 0)
		* maxi(_last_sector.y - _first_sector.y + 1, 0)
	)


func _contains_sector(x: int, y: int) -> bool:
	return (
		x >= _first_sector.x
		and x <= _last_sector.x
		and y >= _first_sector.y
		and y <= _last_sector.y
	)


func _publish_snapshot(sector_count: int) -> void:
	if projection == null:
		return
	_last_snapshot = {
		"generation": generation_id,
		"lod": lod,
		"loading": loading,
		"bounds": projection.bounds(),
		"center": projection.center_global,
		"view_height": projection.view_height,
		"systems": _systems.duplicate(),
		"cells": _cells.duplicate(),
		"catalog_systems": _catalog_systems.duplicate(),
		"visible_rect": visible_rect,
		"preload_rect": preload_rect,
		"error_count": error_count,
		"sector_count": sector_count,
	}
	snapshot_changed.emit(snapshot())
