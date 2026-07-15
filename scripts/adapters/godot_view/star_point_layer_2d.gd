class_name StarPointLayer2D
extends Control

const Palette = preload("res://scripts/visuals/visual_palette.gd")

var settings
var systems: Array = []
var camera_global := Vector2.ZERO
var zoom := 1.0
var viewport_size := Vector2.ONE
var suppressed_ids := {}


func _init(configuration) -> void:
	settings = configuration
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_snapshot(
	next_systems: Array,
	next_camera_global: Vector2,
	next_zoom: float,
	next_viewport_size: Vector2,
	next_suppressed_ids := {}
) -> void:
	systems = next_systems.duplicate()
	camera_global = next_camera_global
	zoom = next_zoom
	viewport_size = next_viewport_size
	suppressed_ids = next_suppressed_ids.duplicate()
	queue_redraw()


func _draw() -> void:
	if viewport_size.y <= 0.0:
		return
	for entry in systems:
		if suppressed_ids.has(entry.id):
			continue
		var pixel := world_to_pixel(entry.global_position)
		if pixel.x < 0.0 or pixel.y < 0.0 or pixel.x > size.x or pixel.y > size.y:
			continue
		var style: Dictionary = Palette.star_style(entry.visual_type, settings)
		var radius := clampf(
			float(style.scale) * 2.0,
			settings.stellar_point_size_range.x,
			settings.stellar_point_size_range.y
		)
		draw_circle(pixel, radius, style.color)


func world_to_pixel(world: Vector2) -> Vector2:
	var scale := viewport_size.y / maxf(zoom, 0.000001)
	return viewport_size * 0.5 + (world - camera_global) * scale
