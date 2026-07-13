class_name VisibleSectorProjection
extends RefCounted

const Scale = preload("res://scripts/domain/universe/universe_scale.gd")
const LOAD_MARGIN := 1
const UNLOAD_MARGIN := 1
const MINIMUM_ASPECT_RATIO := 0.25
const MAXIMUM_ASPECT_RATIO := 4.0


func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var half_height := maxf(orthographic_size, 0.0) * 0.5
	var safe_aspect_ratio := clampf(
		aspect_ratio,
		MINIMUM_ASPECT_RATIO,
		MAXIMUM_ASPECT_RATIO
	)
	var half_width := half_height * safe_aspect_ratio
	return Vector2i(
		ceili(half_width / Scale.SECTOR_SIZE) + LOAD_MARGIN,
		ceili(half_height / Scale.SECTOR_SIZE) + LOAD_MARGIN
	)


func unload_radii(load: Vector2i) -> Vector2i:
	return load + Vector2i(UNLOAD_MARGIN, UNLOAD_MARGIN)


func load_order(
	center,
	active_keys: Dictionary,
	queued_keys: Dictionary,
	radii := Vector2i(2, 2)
) -> Array:
	var result := []
	for y in range(-radii.y, radii.y + 1):
		for x in range(-radii.x, radii.x + 1):
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


func unload_coordinates(
	center,
	active_coordinates: Array,
	radii := Vector2i(3, 3)
) -> Array:
	return active_coordinates.filter(
		func(coordinate):
			return (
				absi(coordinate.x - center.x) > radii.x
				or absi(coordinate.y - center.y) > radii.y
			)
	)
