class_name VisibleSectorProjection
extends RefCounted

const DefaultSettings = preload("res://config/game_settings.tres")

var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration


func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var effective_render_scale := _effective_render_scale(orthographic_size)
	var scaled_half_height: float = (
		maxf(orthographic_size, 0.0)
		* 0.5
		* effective_render_scale
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


func _effective_render_scale(orthographic_size: float) -> float:
	var zoom_span: float = settings.camera_max_zoom - settings.camera_min_zoom
	if zoom_span <= 0.0:
		return settings.stream_render_scale
	var zoom_progress := clampf(
		(maxf(orthographic_size, 0.0) - settings.camera_min_zoom) / zoom_span,
		0.0,
		1.0
	)
	return lerpf(1.0, settings.stream_render_scale, zoom_progress)


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
