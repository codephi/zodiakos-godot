extends "res://tests/test_case.gd"

const Settings = preload("res://config/game_settings.tres")
const GameSettingsResource = preload("res://scripts/config/game_settings.gd")


func run() -> void:
	assert_true(
		Settings is GameSettingsResource,
		"central settings use the typed resource"
	)
	assert_equal(Settings.camera_min_zoom, 20.0, "camera minimum zoom")
	assert_equal(Settings.camera_max_zoom, 30000.0, "camera maximum zoom")
	assert_equal(Settings.camera_initial_zoom, 50.0, "camera initial zoom")
	assert_equal(Settings.camera_zoom_factor, 0.88, "camera zoom factor")
	assert_equal(Settings.stream_sectors_per_frame, 2, "stream frame budget")
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
		"system_max_planets",
		-1,
		"system_max_planets must be nonnegative"
	)
	_assert_validation_error(
		"system_max_moons_per_planet",
		-1,
		"system_max_moons_per_planet must be nonnegative"
	)
	_assert_validation_error(
		"system_max_minor_bodies",
		-1,
		"system_max_minor_bodies must be nonnegative"
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
