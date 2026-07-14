class_name VisibleSectorProjection
extends RefCounted

const DefaultSettings = preload("res://config/game_settings.tres")

var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration


func visible_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	return _coverage_radii(orthographic_size, aspect_ratio, 1.0)


func effective_preload_zoom(camera_zoom: float) -> float:
	var safe_camera_zoom := maxf(camera_zoom, 0.0)
	if not settings.stream_use_fixed_preload_zoom:
		return safe_camera_zoom
	return maxf(safe_camera_zoom, settings.stream_fixed_preload_zoom)


func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var visible := visible_radii(orthographic_size, aspect_ratio)
	var expanded := _coverage_radii(
		effective_preload_zoom(orthographic_size),
		aspect_ratio,
		float(settings.stream_viewport_grid_size)
	)
	return Vector2i(maxi(expanded.x, visible.x), maxi(expanded.y, visible.y))


func _coverage_radii(
	orthographic_size: float,
	aspect_ratio: float,
	render_scale: float
) -> Vector2i:
	var scaled_half_height := maxf(orthographic_size, 0.0) * 0.5 * render_scale
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
