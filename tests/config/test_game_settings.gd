extends "res://tests/test_case.gd"

const Settings = preload("res://config/game_settings.tres")
const GameSettingsResource = preload("res://scripts/config/game_settings.gd")


func run() -> void:
	assert_true(
		Settings is GameSettingsResource,
		"central settings use the typed resource"
	)
	assert_equal(Settings.camera_min_zoom, 0.0, "camera minimum zoom")
	assert_equal(Settings.camera_max_zoom, 100.0, "camera maximum zoom")
	assert_equal(Settings.camera_initial_zoom, 50.0, "camera initial zoom")
	assert_equal(Settings.camera_zoom_factor, 0.88, "camera zoom factor")
	assert_equal(Settings.stream_sectors_per_frame, 2, "stream frame budget")
	assert_equal(Settings.stream_viewport_grid_size, 3, "stream viewport grid size")
	assert_true(not Settings.stream_use_fixed_preload_zoom, "fixed preload is opt-in")
	assert_equal(Settings.stream_fixed_preload_zoom, 1000.0, "fixed preload reference zoom")
	assert_equal(Settings.stream_max_pending_sectors, 256, "stream pending cap")
	assert_equal(Settings.stream_load_margin, 0, "stream uses exact rounded coverage")
	assert_equal(Settings.stream_unload_margin, 0, "near zoom releases distant sectors")
	assert_equal(Settings.stream_max_aspect_ratio, 4.0, "stream maximum aspect")
	assert_equal(Settings.universe_global_seed, 0x5A4F4449414B4F53, "global seed")
	assert_equal(Settings.universe_sector_size, 40.0, "sector size")
	assert_equal(Settings.galaxy_disk_radius_pc, 50000.0, "disk radius")
	assert_equal(Settings.galaxy_halo_radius_pc, 60000.0, "halo radius")
	assert_equal(Settings.galaxy_disk_scale_length_pc, 2600.0, "disk scale")
	assert_equal(Settings.galaxy_bulge_scale_radius_pc, 1000.0, "bulge scale")
	assert_equal(Settings.galaxy_bar_half_length_pc, 5000.0, "bar length")
	assert_equal(Settings.galaxy_bar_axis_ratio, 0.4, "bar axis ratio")
	assert_equal(Settings.galaxy_bar_angle_deg, 27.0, "bar angle")
	assert_equal(Settings.galaxy_spiral_arm_count, 4, "spiral arms")
	assert_equal(Settings.galaxy_spiral_pitch_deg, 12.5, "spiral pitch")
	assert_equal(Settings.galaxy_spiral_arm_width_pc, 500.0, "spiral width")
	assert_equal(Settings.galaxy_halo_weight, 0.02, "halo weight")
	assert_equal(
		Settings.galaxy_max_candidate_systems_per_sector,
		32,
		"candidate cap"
	)
	assert_equal(Settings.universe_minimum_system_distance, 1.5, "system spacing")
	assert_equal(Settings.system_min_stars, 1, "minimum stars")
	assert_equal(Settings.system_max_stars, 3, "maximum stars")
	assert_equal(Settings.system_max_planets, 12, "planet cap")
	assert_equal(Settings.system_max_moons_per_planet, 4, "moon cap")
	assert_equal(Settings.system_max_minor_bodies, 8, "minor body cap")
	assert_true(Settings.performance_metrics_enabled, "performance metrics enabled")
	assert_equal(Settings.performance_metrics_sample_capacity, 240, "metrics sample capacity")
	assert_equal(Settings.minimap_compact_size, Vector2(320.0, 220.0), "minimap compact size")
	assert_equal(Settings.minimap_expanded_screen_ratio, 0.7, "minimap expanded ratio")
	assert_equal(Settings.minimap_initial_view_scale, 9.0, "minimap initial scale")
	assert_equal(Settings.minimap_zoom_factor, 0.8, "minimap zoom factor")
	assert_equal(Settings.minimap_min_view_height, 40.0, "minimap minimum height")
	assert_equal(Settings.minimap_max_view_height, 120000.0, "minimap maximum height")
	assert_equal(Settings.minimap_exact_sector_limit, 256, "minimap exact limit")
	assert_equal(Settings.minimap_cluster_sector_limit, 4096, "minimap cluster limit")
	assert_equal(Settings.minimap_query_sectors_per_frame, 8, "minimap sector budget")
	assert_equal(Settings.minimap_cluster_grid_resolution, 24, "minimap cluster resolution")
	assert_equal(Settings.minimap_density_grid_resolution, 64, "minimap density resolution")
	assert_equal(Settings.minimap_density_cells_per_frame, 128, "minimap cell budget")
	assert_equal(Settings.minimap_cache_sector_limit, 512, "minimap cache limit")
	assert_equal(Settings.minimap_query_debounce_seconds, 0.1, "minimap debounce")
	assert_equal(Settings.stellar_lod_glow_enter_zoom, 200.0, "stellar glow entry")
	assert_equal(Settings.stellar_lod_glow_exit_zoom, 220.0, "stellar glow exit")
	assert_equal(Settings.stellar_lod_safety_margin_ratio, 0.5, "stellar safety margin")
	assert_equal(Settings.stellar_glow_profiles_per_frame, 512, "stellar profile budget")
	assert_equal(Settings.stellar_selection_radius_pixels, 12.0, "stellar selection radius")
	assert_equal(Settings.stellar_glow_visual_period_range, Vector2(2.5, 8.0), "pulse period range")
	assert_equal(Settings.stellar_physics_model_version, 1, "stellar physics version")
	assert_true(Settings.stellar_spectral_profiles.has(&"G"), "spectral profiles include G")
	assert_equal(
		Settings.system_planet_types,
		[&"rocky", &"gas", &"ice", &"volcanic"],
		"planet types"
	)
	assert_equal(Settings.system_planet_type_weights, [45, 20, 25, 10], "planet weights")
	assert_equal(
		Settings.universe_visual_type_weights,
		[35, 25, 20, 15, 5],
		"visual weights"
	)
	assert_equal(Settings.star_styles[&"yellow"].scale, 1.0, "yellow star scale")
	assert_equal(
		Settings.ship_prism_size,
		Vector3(0.8, 0.3, 1.4),
		"ship base mesh"
	)
	assert_equal(Settings.material_emission_multiplier, 1.8, "material emission")
	assert_true(Settings.is_valid(), "production settings are valid")
	assert_equal(
		Settings.validation_errors(),
		PackedStringArray(),
		"valid settings have no errors"
	)

	var invalid = Settings.duplicate(true)
	invalid.camera_min_zoom = invalid.camera_max_zoom + 1.0
	invalid.camera_zoom_factor = 1.0
	invalid.stream_min_aspect_ratio = 0.0
	invalid.galaxy_bar_axis_ratio = 0.0
	var empty_visual_types: Array[StringName] = []
	var empty_visual_weights: Array[int] = []
	invalid.universe_visual_types = empty_visual_types
	invalid.universe_visual_type_weights = empty_visual_weights
	var errors: PackedStringArray = invalid.validation_errors()
	assert_true(errors.size() >= 5, "validation reports every invalid relationship")
	assert_true(not invalid.is_valid(), "invalid settings are rejected")

	_assert_validation_error(
		"camera_min_zoom",
		-0.01,
		"camera_min_zoom must be nonnegative"
	)
	_assert_validation_error(
		&"stream_viewport_grid_size",
		0,
		"stream_viewport_grid_size must be positive"
	)
	_assert_validation_error(
		&"stream_viewport_grid_size",
		2,
		"stream_viewport_grid_size must be odd"
	)
	_assert_validation_error(
		&"stream_fixed_preload_zoom",
		-0.01,
		"stream_fixed_preload_zoom must be nonnegative"
	)
	_assert_validation_error(
		&"stream_fixed_preload_zoom",
		NAN,
		"stream_fixed_preload_zoom must be nonnegative"
	)
	_assert_validation_error(
		&"stream_fixed_preload_zoom",
		INF,
		"stream_fixed_preload_zoom must be nonnegative"
	)
	_assert_validation_error(
		&"stream_max_pending_sectors",
		0,
		"stream_max_pending_sectors must be positive"
	)

	var minimum_grid = Settings.duplicate(true)
	minimum_grid.stream_viewport_grid_size = 1
	assert_true(minimum_grid.is_valid(), "one viewport remains valid")
	var larger_grid = Settings.duplicate(true)
	larger_grid.stream_viewport_grid_size = 5
	assert_true(larger_grid.is_valid(), "larger odd viewport grids remain valid")
	var zero_fixed_zoom = Settings.duplicate(true)
	zero_fixed_zoom.stream_fixed_preload_zoom = 0.0
	assert_true(zero_fixed_zoom.is_valid(), "zero fixed preload zoom remains valid")
	_assert_validation_error(
		"galaxy_disk_scale_length_pc",
		0.0,
		"galaxy_disk_scale_length_pc must be positive"
	)
	_assert_validation_error(
		"galaxy_bulge_scale_radius_pc",
		0.0,
		"galaxy_bulge_scale_radius_pc must be positive"
	)
	_assert_validation_error(
		"galaxy_bar_half_length_pc",
		0.0,
		"galaxy_bar_half_length_pc must be positive"
	)
	_assert_validation_error(
		"galaxy_spiral_arm_count",
		0,
		"galaxy_spiral_arm_count must be positive"
	)
	_assert_validation_error(
		"galaxy_spiral_pitch_deg",
		0.0,
		"galaxy_spiral_pitch_deg must be positive"
	)
	_assert_validation_error(
		"galaxy_spiral_arm_width_pc",
		0.0,
		"galaxy_spiral_arm_width_pc must be positive"
	)
	_assert_validation_error(
		"galaxy_max_candidate_systems_per_sector",
		0,
		"galaxy_max_candidate_systems_per_sector must be positive"
	)
	_assert_validation_error(
		"universe_minimum_system_distance",
		0.0,
		"universe_minimum_system_distance must be positive"
	)
	_assert_validation_error(
		"galaxy_bar_axis_ratio",
		0.0,
		"galaxy_bar_axis_ratio must satisfy 0 < value <= 1"
	)
	_assert_validation_error(
		"galaxy_bar_axis_ratio",
		1.01,
		"galaxy_bar_axis_ratio must satisfy 0 < value <= 1"
	)
	_assert_validation_error(
		"galaxy_halo_weight",
		-0.01,
		"galaxy_halo_weight must be between 0 and 1"
	)
	_assert_validation_error(
		"galaxy_halo_weight",
		1.01,
		"galaxy_halo_weight must be between 0 and 1"
	)
	_assert_validation_error(
		"system_min_stars",
		0,
		"system star count must satisfy 1 <= minimum <= maximum"
	)
	_assert_validation_error(
		"system_max_stars",
		0,
		"system star count must satisfy 1 <= minimum <= maximum"
	)
	_assert_validation_error(
		"system_max_stars",
		27,
		"system_max_stars must be at most 26"
	)
	_assert_validation_error(
		"system_max_planets",
		-1,
		"system_max_planets must be nonnegative"
	)
	_assert_validation_error(
		"system_max_planets",
		26,
		"system_max_planets must be at most 25"
	)
	_assert_validation_error(
		"system_max_moons_per_planet",
		-1,
		"system_max_moons_per_planet must be nonnegative"
	)
	_assert_validation_error(
		"system_max_moons_per_planet",
		4000,
		"system_max_moons_per_planet must be at most 3999"
	)
	_assert_validation_error(
		"system_max_minor_bodies",
		-1,
		"system_max_minor_bodies must be nonnegative"
	)
	_assert_validation_error(
		&"performance_metrics_sample_capacity",
		0,
		"performance_metrics_sample_capacity must be positive"
	)
	_assert_validation_error(
		&"minimap_expanded_screen_ratio",
		1.01,
		"minimap_expanded_screen_ratio must satisfy 0 < value <= 1"
	)
	_assert_validation_error(
		&"minimap_zoom_factor",
		1.0,
		"minimap_zoom_factor must satisfy 0 < value < 1"
	)
	_assert_validation_error(
		&"minimap_query_sectors_per_frame",
		0,
		"minimap_query_sectors_per_frame must be positive"
	)
	_assert_validation_error(
		&"minimap_query_debounce_seconds",
		NAN,
		"minimap_query_debounce_seconds must be nonnegative"
	)
	_assert_validation_error(
		&"stellar_glow_profiles_per_frame",
		0,
		"stellar_glow_profiles_per_frame must be positive"
	)
	var invalid_stellar_order = Settings.duplicate(true)
	invalid_stellar_order.stellar_lod_glow_enter_zoom = 220.0
	assert_true(
		invalid_stellar_order.validation_errors().has(
			"stellar LOD zooms must satisfy entry < exit"
		),
		"stellar LOD thresholds are ordered"
	)
	var invalid_minimap_order = Settings.duplicate(true)
	invalid_minimap_order.minimap_exact_sector_limit = 4096
	assert_true(
		invalid_minimap_order.validation_errors().has(
			"minimap sector limits must satisfy exact < cluster"
		),
		"minimap exact threshold remains below cluster threshold"
	)

	_assert_planet_type_validation(
		[],
		[],
		"system_planet_types must not be empty"
	)
	_assert_planet_type_validation(
		[&"rocky", &"gas"],
		[1],
		"system planet types and weights must have matching sizes"
	)
	_assert_planet_type_validation(
		[&"rocky", &"rocky"],
		[1, 1],
		"system_planet_types must contain unique values"
	)
	_assert_planet_type_validation(
		[&"rocky", &"ocean"],
		[1, 1],
		"system_planet_types contains unsupported value: ocean"
	)
	_assert_planet_type_validation(
		[&"rocky"],
		[0],
		"system_planet_type_weights must contain positive values"
	)

	var repeated_aggregate_errors = Settings.duplicate(true)
	var repeated_types: Array[StringName] = [&"rocky", &"rocky", &"rocky"]
	var invalid_weights: Array[int] = [0, -1, 1]
	repeated_aggregate_errors.system_planet_types = repeated_types
	repeated_aggregate_errors.system_planet_type_weights = invalid_weights
	var aggregate_errors: PackedStringArray = repeated_aggregate_errors.validation_errors()
	assert_equal(
		aggregate_errors.count("system_planet_types must contain unique values"),
		1,
		"duplicate type diagnostic appears once"
	)
	assert_equal(
		aggregate_errors.count(
			"system_planet_type_weights must contain positive values"
		),
		1,
		"invalid weight diagnostic appears once"
	)

	var missing_enabled_style = Settings.duplicate(true)
	missing_enabled_style.planet_styles.erase(&"gas")
	assert_true(
		missing_enabled_style.validation_errors().has(
			"system_planet_types has no planet_styles entry: gas"
		),
		"every enabled procedural planet type requires a visual style"
	)
	assert_true(not missing_enabled_style.is_valid(), "missing enabled style is invalid")

	var invalid_radii = Settings.duplicate(true)
	invalid_radii.galaxy_disk_radius_pc = invalid_radii.galaxy_halo_radius_pc
	assert_true(
		invalid_radii.validation_errors().has(
			"galaxy radii must satisfy disk radius < halo radius"
		),
		"disk radius must remain smaller than halo radius"
	)


func _assert_validation_error(
	field_name: StringName,
	value: Variant,
	expected_error: String
) -> void:
	var invalid = Settings.duplicate(true)
	invalid.set(field_name, value)
	assert_true(
		invalid.validation_errors().has(expected_error),
		"%s rejects %s" % [field_name, value]
	)


func _assert_planet_type_validation(
	types: Array[StringName],
	weights: Array[int],
	expected_error: String
) -> void:
	var invalid = Settings.duplicate(true)
	invalid.system_planet_types = types
	invalid.system_planet_type_weights = weights
	assert_true(
		invalid.validation_errors().has(expected_error),
		"planet composition rejects invalid type configuration"
	)
