extends "res://tests/test_case.gd"

const VisualPalette = preload("res://scripts/visuals/visual_palette.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	assert_equal(VisualPalette.ship_style(&"expedition").scale, 0.7, "expedition scale")
	assert_equal(VisualPalette.ship_style(&"colony").scale, 1.0, "colony scale")
	assert_equal(VisualPalette.ship_style(&"war").scale, 1.3, "war scale")
	assert_equal(
		VisualPalette.ship_style(&"unknown"),
		VisualPalette.ship_style(&"expedition"),
		"ship fallback"
	)
	assert_equal(
		VisualPalette.star_style(&"unknown"),
		VisualPalette.star_style(&"yellow"),
		"star fallback"
	)
	assert_equal(
		VisualPalette.planet_style(&"unknown"),
		VisualPalette.planet_style(&"rocky"),
		"planet fallback"
	)
	assert_equal(
		VisualPalette.normalize_owner_color(Color(0.0, 0.0, 0.0, 0.0)),
		Color(0.5, 0.5, 0.5, 1.0),
		"owner fallback"
	)
	var custom = Settings.duplicate(true)
	custom.ship_styles[&"expedition"].scale = 2.0
	custom.neutral_owner_color = Color.MAGENTA
	assert_equal(
		VisualPalette.ship_style(&"expedition", custom).scale,
		2.0,
		"ship style comes from injected settings"
	)
	assert_equal(
		VisualPalette.normalize_owner_color(Color.TRANSPARENT, custom),
		Color.MAGENTA,
		"owner fallback comes from injected settings"
	)
