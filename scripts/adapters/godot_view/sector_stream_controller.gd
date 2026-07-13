class_name SectorStreamController
extends Node

signal stats_changed(active_sectors: int, visible_stars: int, center_key: String)

const ProjectionScript = preload(
	"res://scripts/application/projections/visible_sector_projection.gd"
)

var generator
var view
var center
var pending := []
var queued := {}
var projection = ProjectionScript.new()
var _last_stats := []


func configure(source_generator, target_view, initial_position) -> void:
	generator = source_generator
	view = target_view
	update_center(initial_position)


func update_center(position) -> void:
	center = position.sector.offset(0, 0)
	view.rebase(center)
	pending.clear()
	queued.clear()
	for coordinate in projection.load_order(center, view.active_keys(), queued):
		pending.append(coordinate)
		queued[coordinate.key()] = true
	for coordinate in projection.unload_coordinates(center, view.active_coordinates()):
		view.remove_sector(coordinate)
	_emit_stats()


func _process(_delta: float) -> void:
	process_pending()


func process_pending(limit := 2) -> void:
	var batch_size := mini(maxi(limit, 0), pending.size())
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
