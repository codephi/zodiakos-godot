class_name SectorStreamController
extends Node

signal stats_changed(active_sectors: int, visible_stars: int, center_key: String)

const ProjectionScript = preload(
	"res://scripts/application/projections/visible_sector_projection.gd"
)
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var generator
var view
var center
var pending := []
var queued := {}
var projection
var load_radii: Vector2i
var unload_radii: Vector2i
var _last_stats := []


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	projection = ProjectionScript.new(settings)
	load_radii = settings.stream_initial_load_radii
	unload_radii = projection.unload_radii(load_radii)


func configure(source_generator, target_view, initial_position) -> void:
	generator = source_generator
	view = target_view
	update_center(initial_position)


func update_center(position) -> void:
	var next_center = position.sector.offset(0, 0)
	if center != null and center.equals(next_center):
		return
	center = next_center
	_reconcile_stream()


func update_view(orthographic_size: float, viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var next_load: Vector2i = projection.load_radii(
		orthographic_size,
		viewport_size.x / viewport_size.y
	)
	if next_load != load_radii:
		load_radii = next_load
		unload_radii = projection.unload_radii(load_radii)
	_reconcile_stream()


func _reconcile_stream() -> void:
	view.rebase(center)
	pending.clear()
	queued.clear()
	for coordinate in projection.load_order(center, view.active_keys(), queued, load_radii):
		pending.append(coordinate)
		queued[coordinate.key()] = true
	for coordinate in projection.unload_coordinates(
		center,
		view.active_coordinates(),
		unload_radii
	):
		view.remove_sector(coordinate)
	_emit_stats()


func _process(_delta: float) -> void:
	process_pending()


func process_pending(limit = null) -> void:
	var requested_limit: int = settings.stream_sectors_per_frame if limit == null else limit
	var batch_size := mini(maxi(requested_limit, 0), pending.size())
	for _index in batch_size:
		var coordinate = pending.pop_front()
		queued.erase(coordinate.key())
		view.materialize_sector(generator.generate_sector(coordinate), center)
	_emit_stats()


func _emit_stats() -> void:
	if center == null:
		return
	var current_stats := [view.active_sector_count(), view.star_count(), center.key()]
	if current_stats == _last_stats:
		return
	_last_stats = current_stats
	stats_changed.emit(current_stats[0], current_stats[1], current_stats[2])
