class_name SectorStreamController
extends Node

signal stats_changed(active_sectors: int, visible_systems: int, center_key: String)

const ProjectionScript = preload(
	"res://scripts/application/projections/visible_sector_projection.gd"
)
const PrioritizedSectorIterator = preload(
	"res://scripts/application/streaming/prioritized_sector_iterator.gd"
)
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var generator
var view
var center
var pending := []
var queued := {}
var projection
var visible_radii: Vector2i
var load_radii: Vector2i
var unload_radii: Vector2i
var _last_stats := []
var _iterator


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	projection = ProjectionScript.new(settings)
	visible_radii = settings.stream_initial_load_radii
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
	_reconcile_stream(true)


func update_view(orthographic_size: float, viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var aspect_ratio := viewport_size.x / viewport_size.y
	var next_visible: Vector2i = projection.visible_radii(
		orthographic_size,
		aspect_ratio
	)
	var next_load: Vector2i = projection.load_radii(orthographic_size, aspect_ratio)
	var coverage_changed := next_visible != visible_radii or next_load != load_radii
	if coverage_changed:
		visible_radii = next_visible
		load_radii = next_load
		unload_radii = projection.unload_radii(load_radii)
	_reconcile_stream(coverage_changed)


func _reconcile_stream(reset_schedule := false) -> void:
	view.rebase(center)
	if reset_schedule or _iterator == null:
		pending.clear()
		queued.clear()
		_iterator = PrioritizedSectorIterator.new(center, visible_radii, load_radii)
		_refill_pending()
	for coordinate in projection.unload_coordinates(
		center,
		view.active_coordinates(),
		unload_radii
	):
		view.remove_sector(coordinate)
	_emit_stats()


func _refill_pending() -> void:
	if _iterator == null:
		return
	var active_keys: Dictionary = view.active_keys()
	var scanned := 0
	while (
		pending.size() < settings.stream_max_pending_sectors
		and scanned < settings.stream_max_pending_sectors
	):
		var coordinate = _iterator.next_coordinate()
		if coordinate == null:
			return
		scanned += 1
		var key: String = coordinate.key()
		if active_keys.has(key) or queued.has(key):
			continue
		pending.append(coordinate)
		queued[key] = true


func _process(_delta: float) -> void:
	process_pending()


func process_pending(limit = null) -> void:
	var requested_limit: int = settings.stream_sectors_per_frame if limit == null else limit
	var batch_size := mini(maxi(requested_limit, 0), pending.size())
	for _index in batch_size:
		var coordinate = pending.pop_front()
		queued.erase(coordinate.key())
		view.materialize_sector(generator.generate_sector(coordinate), center)
	_refill_pending()
	_emit_stats()


func _emit_stats() -> void:
	if center == null:
		return
	var current_stats := [view.active_sector_count(), view.system_count(), center.key()]
	if current_stats == _last_stats:
		return
	_last_stats = current_stats
	stats_changed.emit(current_stats[0], current_stats[1], current_stats[2])
