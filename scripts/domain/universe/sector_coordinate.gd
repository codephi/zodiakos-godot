class_name SectorCoordinate
extends RefCounted

var x: int
var y: int


func _init(initial_x := 0, initial_y := 0) -> void:
	x = initial_x
	y = initial_y


func key() -> String:
	return "%d:%d" % [x, y]


func offset(delta_x: int, delta_y: int):
	return get_script().new(x + delta_x, y + delta_y)


func equals(other) -> bool:
	return other != null and x == other.x and y == other.y


func chebyshev_distance(other) -> int:
	return maxi(absi(x - other.x), absi(y - other.y))
