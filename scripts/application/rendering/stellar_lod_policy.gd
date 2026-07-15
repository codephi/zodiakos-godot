class_name StellarLodPolicy
extends RefCounted

const POINTS_2D := &"points_2d"
const STELLAR_GLOW := &"stellar_glow"

var settings


func _init(configuration) -> void:
	settings = configuration


func next_mode(current_mode: StringName, zoom: float) -> StringName:
	if zoom < settings.stellar_lod_glow_enter_zoom:
		return STELLAR_GLOW
	if zoom >= settings.stellar_lod_glow_exit_zoom:
		return POINTS_2D
	return current_mode


func coverage_rect(visible_rect: Rect2) -> Rect2:
	var growth: Vector2 = visible_rect.size * settings.stellar_lod_safety_margin_ratio
	return visible_rect.grow_individual(growth.x, growth.y, growth.x, growth.y)
