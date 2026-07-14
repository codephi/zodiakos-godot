class_name PrioritizedSectorIterator
extends RefCounted

const SectorRingIterator = preload(
	"res://scripts/application/streaming/sector_ring_iterator.gd"
)

var _center: SectorCoordinate
var _visible_radii: Vector2i
var _visible_iterator
var _expanded_iterator
var _visible_exhausted := false
var _exhausted := false


func _init(center: SectorCoordinate, visible_radii: Vector2i, load_radii: Vector2i) -> void:
	assert(center != null, "Prioritized iterator requires a center")
	assert(
		visible_radii.x >= 0 and visible_radii.y >= 0,
		"Visible radii must be nonnegative"
	)
	assert(
		load_radii.x >= visible_radii.x and load_radii.y >= visible_radii.y,
		"Load radii must contain visible radii"
	)
	_center = center.offset(0, 0)
	_visible_radii = visible_radii
	_visible_iterator = SectorRingIterator.new(_center, visible_radii)
	_expanded_iterator = SectorRingIterator.new(_center, load_radii)


func next_coordinate():
	if _exhausted:
		return null
	if not _visible_exhausted:
		var visible_coordinate = _visible_iterator.next_coordinate()
		if visible_coordinate != null:
			return visible_coordinate
		_visible_exhausted = true
	while true:
		var expanded_coordinate = _expanded_iterator.next_coordinate()
		if expanded_coordinate == null:
			_exhausted = true
			return null
		if not _inside_visible(expanded_coordinate):
			return expanded_coordinate
	return null


func is_exhausted() -> bool:
	return _exhausted


func _inside_visible(coordinate: SectorCoordinate) -> bool:
	return (
		absi(coordinate.x - _center.x) <= _visible_radii.x
		and absi(coordinate.y - _center.y) <= _visible_radii.y
	)
