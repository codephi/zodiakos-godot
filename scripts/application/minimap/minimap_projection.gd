class_name MinimapProjection
extends RefCounted

var center_global: Vector2
var view_height: float
var aspect_ratio: float


func _init(center: Vector2, height: float, aspect: float) -> void:
	center_global = center
	view_height = maxf(height, 0.000001)
	aspect_ratio = maxf(aspect, 0.000001)


func bounds() -> Rect2:
	var bounds_size := Vector2(view_height * aspect_ratio, view_height)
	return Rect2(center_global - bounds_size * 0.5, bounds_size)


func world_to_pixel(world: Vector2, drawing_rect: Rect2) -> Vector2:
	var current_bounds := bounds()
	var normalized := (world - current_bounds.position) / current_bounds.size
	return drawing_rect.position + normalized * drawing_rect.size


func pixel_to_world(pixel: Vector2, drawing_rect: Rect2) -> Vector2:
	if drawing_rect.size.x <= 0.0 or drawing_rect.size.y <= 0.0:
		return center_global
	var normalized := (pixel - drawing_rect.position) / drawing_rect.size
	var current_bounds := bounds()
	return current_bounds.position + normalized * current_bounds.size


func zoom_at(
	steps: int,
	cursor_pixel: Vector2,
	drawing_rect: Rect2,
	zoom_factor: float,
	minimum_height: float,
	maximum_height: float
):
	var anchored_world := pixel_to_world(cursor_pixel, drawing_rect)
	var next_height := view_height
	if steps > 0:
		next_height *= pow(zoom_factor, steps)
	elif steps < 0:
		next_height /= pow(zoom_factor, -steps)
	next_height = clampf(next_height, minimum_height, maximum_height)
	var result = get_script().new(center_global, next_height, aspect_ratio)
	var shifted_world: Vector2 = result.pixel_to_world(cursor_pixel, drawing_rect)
	result.center_global += anchored_world - shifted_world
	return result
