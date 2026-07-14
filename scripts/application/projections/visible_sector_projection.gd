class_name VisibleSectorProjection
extends RefCounted

const DefaultSettings = preload("res://config/game_settings.tres")

var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration


func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var scaled_half_height: float = (
		maxf(orthographic_size, 0.0)
		* 0.5
		* settings.stream_render_scale
	)
	var safe_aspect_ratio := clampf(
		aspect_ratio,
		settings.stream_min_aspect_ratio,
		settings.stream_max_aspect_ratio
	)
	var scaled_half_width: float = scaled_half_height * safe_aspect_ratio
	return Vector2i(
		ceili(scaled_half_width / settings.universe_sector_size)
			+ settings.stream_load_margin,
		ceili(scaled_half_height / settings.universe_sector_size)
			+ settings.stream_load_margin
	)


func unload_radii(load: Vector2i) -> Vector2i:
	return load + Vector2i(settings.stream_unload_margin, settings.stream_unload_margin)


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
