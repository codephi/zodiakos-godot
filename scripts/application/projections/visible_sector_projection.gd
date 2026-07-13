class_name VisibleSectorProjection
extends RefCounted

const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 3


func load_order(center, active_keys: Dictionary, queued_keys: Dictionary) -> Array:
	var result := []
	for y in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for x in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coordinate = center.offset(x, y)
			var key: String = coordinate.key()
			if not active_keys.has(key) and not queued_keys.has(key):
				result.append(coordinate)
	result.sort_custom(func(left, right):
		var left_distance: int = left.chebyshev_distance(center)
		var right_distance: int = right.chebyshev_distance(center)
		if left_distance != right_distance:
			return left_distance < right_distance
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x
	)
	return result


func unload_coordinates(center, active_coordinates: Array) -> Array:
	return active_coordinates.filter(
		func(coordinate): return coordinate.chebyshev_distance(center) > UNLOAD_RADIUS
	)
