class_name GameSettings
extends Resource

const SUPPORTED_PLANET_TYPES: Array[StringName] = [
	&"rocky",
	&"gas",
	&"ice",
	&"volcanic",
]
const SYSTEM_MAX_STARS_LIMIT := 26
const SYSTEM_MAX_PLANETS_LIMIT := 25
const SYSTEM_MAX_MOONS_PER_PLANET_LIMIT := 3999

@export_category("Map Camera")
@export var camera_min_zoom: float
@export var camera_max_zoom: float
@export var camera_initial_zoom: float
@export var camera_zoom_factor: float
@export var camera_height: float
@export var camera_drag_threshold_pixels: float

@export_category("Map Streaming")
@export var stream_initial_load_radii: Vector2i
@export var stream_render_scale: float
@export var stream_load_margin: int
@export var stream_unload_margin: int
@export var stream_min_aspect_ratio: float
@export var stream_max_aspect_ratio: float
@export var stream_sectors_per_frame: int

@export_category("Procedural Universe")
@export var universe_global_seed: int
@export var universe_generator_version: int
@export var universe_sector_size: float
@export var universe_minimum_system_distance: float
@export var universe_visual_types: Array[StringName]
@export var universe_visual_type_weights: Array[int]

@export_category("Galaxy Shape")
@export var galaxy_disk_radius_pc: float
@export var galaxy_halo_radius_pc: float
@export var galaxy_disk_scale_length_pc: float
@export var galaxy_bulge_scale_radius_pc: float
@export var galaxy_bar_half_length_pc: float
@export var galaxy_bar_axis_ratio: float
@export var galaxy_bar_angle_deg: float
@export var galaxy_spiral_arm_count: int
@export var galaxy_spiral_pitch_deg: float
@export var galaxy_spiral_arm_width_pc: float
@export var galaxy_halo_weight: float
@export var galaxy_max_candidate_systems_per_sector: int

@export_category("Procedural System Composition")
@export var system_min_stars: int
@export var system_max_stars: int
@export var system_max_planets: int
@export var system_max_moons_per_planet: int
@export var system_max_minor_bodies: int
@export var system_planet_types: Array[StringName]
@export var system_planet_type_weights: Array[int]

@export_category("Performance Metrics")
@export var performance_metrics_enabled: bool
@export var performance_metrics_sample_capacity: int

@export_category("Visual Palette")
@export var neutral_owner_color: Color
@export var ship_styles: Dictionary
@export var star_styles: Dictionary
@export var planet_styles: Dictionary

@export_category("Geometric Visuals")
@export var star_sphere_radial_segments: int
@export var star_sphere_rings: int
@export var planet_sphere_radial_segments: int
@export var planet_sphere_rings: int
@export var planet_minimum_scale: float
@export var ring_thickness: float
@export var ring_rings: int
@export var ring_segments: int
@export var star_selected_ring_radius: float
@export var star_owner_ring_radius: float
@export var ship_owner_ring_radius: float
@export var ship_owner_ring_height: float
@export var ship_prism_size: Vector3
@export var zodiac_area_opacity: float
@export var material_emission_multiplier: float

@export_category("Map Environment")
@export var map_background_color: Color
@export var map_ambient_light_color: Color
@export var map_ambient_light_energy: float

@export_category("Geometric Demo")
@export var demo_owner_color: Color
@export var demo_camera_position: Vector3
@export var demo_camera_rotation_degrees: Vector3
@export var demo_camera_fov: float
@export var demo_light_rotation_degrees: Vector3
@export var demo_light_energy: float
@export var demo_background_color: Color
@export var demo_ambient_light_color: Color
@export var demo_ambient_light_energy: float
@export var demo_territory_line_thickness: float
@export var demo_route_line_thickness: float
@export var demo_route_color: Color
@export var demo_star_types: Array[StringName]
@export var demo_ship_classes: Array[StringName]
@export var demo_planet_types: Array[StringName]


func is_valid() -> bool:
	return validation_errors().is_empty()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_camera(errors)
	_validate_streaming(errors)
	_validate_universe(errors)
	_validate_galaxy(errors)
	_validate_system_composition(errors)
	_validate_performance_metrics(errors)
	_validate_visuals(errors)
	_validate_demo(errors)
	return errors


func _validate_camera(errors: PackedStringArray) -> void:
	_require_nonnegative(errors, "camera_min_zoom", camera_min_zoom)
	if camera_min_zoom > camera_initial_zoom or camera_initial_zoom > camera_max_zoom:
		errors.append("camera zoom order must be min <= initial <= max")
	if camera_zoom_factor <= 0.0 or camera_zoom_factor >= 1.0:
		errors.append("camera_zoom_factor must be between 0 and 1")
	_require_positive(errors, "camera_height", camera_height)
	_require_positive(errors, "camera_drag_threshold_pixels", camera_drag_threshold_pixels)


func _validate_streaming(errors: PackedStringArray) -> void:
	if stream_initial_load_radii.x < 0 or stream_initial_load_radii.y < 0:
		errors.append("stream_initial_load_radii must be nonnegative")
	if stream_render_scale < 1.0:
		errors.append("stream_render_scale must be at least 1")
	_require_nonnegative(errors, "stream_load_margin", stream_load_margin)
	_require_nonnegative(errors, "stream_unload_margin", stream_unload_margin)
	_require_positive(errors, "stream_min_aspect_ratio", stream_min_aspect_ratio)
	if stream_min_aspect_ratio > stream_max_aspect_ratio:
		errors.append("stream aspect order must be min <= max")
	_require_nonnegative(errors, "stream_sectors_per_frame", stream_sectors_per_frame)


func _validate_universe(errors: PackedStringArray) -> void:
	_require_positive(errors, "universe_generator_version", universe_generator_version)
	_require_positive(errors, "universe_sector_size", universe_sector_size)
	_require_positive(
		errors,
		"universe_minimum_system_distance",
		universe_minimum_system_distance
	)
	if universe_visual_types.is_empty():
		errors.append("universe_visual_types must not be empty")
	if universe_visual_types.size() != universe_visual_type_weights.size():
		errors.append("universe visual types and weights must have matching sizes")
	for visual_type in universe_visual_types:
		if visual_type.is_empty():
			errors.append("universe_visual_types must not contain empty values")
	for weight in universe_visual_type_weights:
		if weight <= 0:
			errors.append("universe_visual_type_weights must contain positive values")


func _validate_galaxy(errors: PackedStringArray) -> void:
	_require_positive(errors, "galaxy_disk_radius_pc", galaxy_disk_radius_pc)
	_require_positive(errors, "galaxy_halo_radius_pc", galaxy_halo_radius_pc)
	_require_positive(errors, "galaxy_disk_scale_length_pc", galaxy_disk_scale_length_pc)
	_require_positive(errors, "galaxy_bulge_scale_radius_pc", galaxy_bulge_scale_radius_pc)
	_require_positive(errors, "galaxy_bar_half_length_pc", galaxy_bar_half_length_pc)
	_require_positive(errors, "galaxy_spiral_arm_count", galaxy_spiral_arm_count)
	_require_positive(errors, "galaxy_spiral_pitch_deg", galaxy_spiral_pitch_deg)
	_require_positive(errors, "galaxy_spiral_arm_width_pc", galaxy_spiral_arm_width_pc)
	_require_positive(
		errors,
		"galaxy_max_candidate_systems_per_sector",
		galaxy_max_candidate_systems_per_sector
	)
	if galaxy_bar_axis_ratio <= 0.0 or galaxy_bar_axis_ratio > 1.0:
		errors.append("galaxy_bar_axis_ratio must satisfy 0 < value <= 1")
	if galaxy_halo_weight < 0.0 or galaxy_halo_weight > 1.0:
		errors.append("galaxy_halo_weight must be between 0 and 1")
	if galaxy_disk_radius_pc >= galaxy_halo_radius_pc:
		errors.append("galaxy radii must satisfy disk radius < halo radius")


func _validate_system_composition(errors: PackedStringArray) -> void:
	if system_min_stars < 1 or system_min_stars > system_max_stars:
		errors.append("system star count must satisfy 1 <= minimum <= maximum")
	if system_max_stars > SYSTEM_MAX_STARS_LIMIT:
		errors.append("system_max_stars must be at most 26")
	_require_nonnegative(errors, "system_max_planets", system_max_planets)
	if system_max_planets > SYSTEM_MAX_PLANETS_LIMIT:
		errors.append("system_max_planets must be at most 25")
	_require_nonnegative(
		errors,
		"system_max_moons_per_planet",
		system_max_moons_per_planet
	)
	if system_max_moons_per_planet > SYSTEM_MAX_MOONS_PER_PLANET_LIMIT:
		errors.append("system_max_moons_per_planet must be at most 3999")
	_require_nonnegative(errors, "system_max_minor_bodies", system_max_minor_bodies)
	if system_planet_types.is_empty():
		errors.append("system_planet_types must not be empty")
	if system_planet_types.size() != system_planet_type_weights.size():
		errors.append("system planet types and weights must have matching sizes")
	var seen_types := {}
	var has_duplicate_type := false
	for planet_type in system_planet_types:
		if seen_types.has(planet_type):
			has_duplicate_type = true
			continue
		seen_types[planet_type] = true
		if not SUPPORTED_PLANET_TYPES.has(planet_type):
			errors.append(
				"system_planet_types contains unsupported value: %s" % planet_type
			)
			continue
		if not planet_styles.has(planet_type):
			errors.append(
				"system_planet_types has no planet_styles entry: %s" % planet_type
			)
	if has_duplicate_type:
		errors.append("system_planet_types must contain unique values")
	var has_nonpositive_weight := false
	for weight in system_planet_type_weights:
		if weight <= 0:
			has_nonpositive_weight = true
	if has_nonpositive_weight:
		errors.append("system_planet_type_weights must contain positive values")


func _validate_performance_metrics(errors: PackedStringArray) -> void:
	_require_positive(
		errors,
		"performance_metrics_sample_capacity",
		performance_metrics_sample_capacity
	)


func _validate_visuals(errors: PackedStringArray) -> void:
	_require_style(errors, ship_styles, &"expedition", "ship_styles")
	_require_style(errors, star_styles, &"yellow", "star_styles")
	_require_style(errors, planet_styles, &"rocky", "planet_styles")
	_require_positive(errors, "star_sphere_radial_segments", star_sphere_radial_segments)
	_require_positive(errors, "star_sphere_rings", star_sphere_rings)
	_require_positive(errors, "planet_sphere_radial_segments", planet_sphere_radial_segments)
	_require_positive(errors, "planet_sphere_rings", planet_sphere_rings)
	_require_positive(errors, "planet_minimum_scale", planet_minimum_scale)
	_require_positive(errors, "ring_thickness", ring_thickness)
	_require_positive(errors, "ring_rings", ring_rings)
	_require_positive(errors, "ring_segments", ring_segments)
	_require_positive(errors, "star_selected_ring_radius", star_selected_ring_radius)
	_require_positive(errors, "star_owner_ring_radius", star_owner_ring_radius)
	_require_positive(errors, "ship_owner_ring_radius", ship_owner_ring_radius)
	if ship_prism_size.x <= 0.0 or ship_prism_size.y <= 0.0 or ship_prism_size.z <= 0.0:
		errors.append("ship_prism_size must have positive components")
	if zodiac_area_opacity < 0.0 or zodiac_area_opacity > 1.0:
		errors.append("zodiac_area_opacity must be between 0 and 1")
	_require_positive(errors, "material_emission_multiplier", material_emission_multiplier)
	_require_nonnegative(errors, "map_ambient_light_energy", map_ambient_light_energy)


func _validate_demo(errors: PackedStringArray) -> void:
	_require_positive(errors, "demo_camera_fov", demo_camera_fov)
	_require_nonnegative(errors, "demo_light_energy", demo_light_energy)
	_require_nonnegative(errors, "demo_ambient_light_energy", demo_ambient_light_energy)
	_require_positive(errors, "demo_territory_line_thickness", demo_territory_line_thickness)
	_require_positive(errors, "demo_route_line_thickness", demo_route_line_thickness)
	if demo_star_types.is_empty():
		errors.append("demo_star_types must not be empty")
	if demo_ship_classes.is_empty():
		errors.append("demo_ship_classes must not be empty")
	if demo_planet_types.is_empty():
		errors.append("demo_planet_types must not be empty")


func _require_style(
	errors: PackedStringArray,
	styles: Dictionary,
	fallback: StringName,
	field_name: String
) -> void:
	if not styles.has(fallback):
		errors.append("%s must contain %s" % [field_name, fallback])


func _require_positive(errors: PackedStringArray, field_name: String, value: float) -> void:
	if value <= 0.0:
		errors.append("%s must be positive" % field_name)


func _require_nonnegative(errors: PackedStringArray, field_name: String, value: float) -> void:
	if value < 0.0:
		errors.append("%s must be nonnegative" % field_name)
