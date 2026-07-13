extends "res://tests/test_case.gd"

const Settings = preload("res://config/game_settings.tres")
const GameSettingsResource = preload("res://scripts/config/game_settings.gd")


func run() -> void:
	assert_true(
		Settings is GameSettingsResource,
		"central settings use the typed resource"
	)
	assert_equal(Settings.camera_min_zoom, 20.0, "camera minimum zoom")
	assert_equal(Settings.camera_max_zoom, 300.0, "camera maximum zoom")
	assert_equal(Settings.camera_initial_zoom, 50.0, "camera initial zoom")
	assert_equal(Settings.camera_zoom_factor, 0.88, "camera zoom factor")
	assert_equal(Settings.stream_sectors_per_frame, 2, "stream frame budget")
	assert_equal(Settings.universe_global_seed, 0x5A4F4449414B4F53, "global seed")
	assert_equal(Settings.universe_sector_size, 40.0, "sector size")
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
	invalid.universe_min_clusters = invalid.universe_max_clusters + 1
	var empty_visual_types: Array[StringName] = []
	var empty_visual_weights: Array[int] = []
	invalid.universe_visual_types = empty_visual_types
	invalid.universe_visual_type_weights = empty_visual_weights
	var errors: PackedStringArray = invalid.validation_errors()
	assert_true(errors.size() >= 5, "validation reports every invalid relationship")
	assert_true(not invalid.is_valid(), "invalid settings are rejected")
