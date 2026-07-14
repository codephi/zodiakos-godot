class_name SectorRingIterator
extends RefCounted

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")

var _center: SectorCoordinate
var _radii: Vector2i
var _maximum_radius: int
var _radius := 0
var _ring_y := 0
var _ring_x := 0
var _exhausted := false


func _init(center: SectorCoordinate, radii: Vector2i) -> void:
	assert(center != null, "Sector ring iterator requires a center")
	assert(radii.x >= 0 and radii.y >= 0, "Sector ring radii must be nonnegative")
	_center = center.offset(0, 0)
	_radii = radii
	_maximum_radius = maxi(radii.x, radii.y)


func next_coordinate():
	if _exhausted:
		return null
	while _radius <= _maximum_radius:
		var offset = _next_ring_offset()
		if offset == null:
			_advance_ring()
			continue
		if absi(offset.x) <= _radii.x and absi(offset.y) <= _radii.y:
			return _center.offset(offset.x, offset.y)
	_exhausted = true
	return null


func is_exhausted() -> bool:
	return _exhausted


func _next_ring_offset():
	if _ring_y > _radius:
		return null
	var offset := Vector2i(_ring_x, _ring_y)
	if _ring_y == -_radius or _ring_y == _radius:
		_ring_x += 1
		if _ring_x > _radius:
			_ring_y += 1
			_ring_x = -_radius
	elif _ring_x == -_radius:
		_ring_x = _radius
	else:
		_ring_y += 1
		_ring_x = -_radius
	return offset


func _advance_ring() -> void:
	_radius += 1
	_ring_y = -_radius
	_ring_x = -_radius
