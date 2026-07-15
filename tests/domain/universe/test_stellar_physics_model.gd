extends "res://tests/test_case.gd"

const Model = preload("res://scripts/domain/universe/stellar_physics_model.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var identity = Identity.new(101, 1, Metadata.new(1, 1, 1), Settings)
	var model = Model.new(Settings)
	var first: Dictionary = model.complete_star_properties(&"same", &"yellow", {}, identity)
	var second: Dictionary = model.complete_star_properties(&"same", &"yellow", {}, identity)
	assert_equal(first, second, "physical completion is deterministic")
	assert_equal(first.spectral_class, &"G", "yellow systems produce G stars")
	assert_true(first.temperature_k >= 5200.0 and first.temperature_k <= 6000.0, "G temperature range")
	var expected: float = pow(first.radius_solar, 2.0) * pow(first.temperature_k / 5772.0, 4.0)
	assert_true(is_equal_approx(first.luminosity_solar, expected), "luminosity follows Stefan-Boltzmann ratio")
	assert_true(first.variability_fraction >= 0.0, "variability is nonnegative")
	assert_true(first.variability_period_days > 0.0, "physical period is positive")

	var catalog := {
		"spectral_class": &"K",
		"temperature_k": 4400.0,
		"mass_solar": 0.7,
		"radius_solar": 0.8,
		"luminosity_solar": 0.21,
	}
	var completed: Dictionary = model.complete_star_properties(&"catalog", &"orange", catalog, identity)
	assert_equal(completed.temperature_k, 4400.0, "catalog temperature is preserved")
	assert_equal(completed.luminosity_solar, 0.21, "catalog luminosity is preserved")
