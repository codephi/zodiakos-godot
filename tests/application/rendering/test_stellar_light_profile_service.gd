extends "res://tests/test_case.gd"

const Service = preload("res://scripts/application/rendering/stellar_light_profile_service.gd")
const Model = preload("res://scripts/domain/universe/stellar_physics_model.gd")
const Body = preload("res://scripts/domain/universe/system_body_definition.gd")
const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")
const Definition = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Settings = preload("res://config/game_settings.tres")


class FakeLoader:
	var composition

	func _init(value) -> void:
		composition = value

	func execute(_definition):
		return composition


func run() -> void:
	var primary = _star(&"primary", 10.0, 0.10, 20.0, 0.25, &"G")
	var secondary = _star(&"secondary", 2.0, 0.01, 8.0, 0.75, &"K", &"primary")
	var composition = Composition.new(&"binary", [primary, secondary], [], [], [], [])
	var definition = Definition.new(
		&"binary", Coordinate.new(), Vector2.ZERO, &"yellow", &"procedural", Coordinate.new(), 1
	)
	var identity = Identity.new(101, 1, Metadata.new(1, 1, 1), Settings)
	var service = Service.new(FakeLoader.new(composition), Model.new(Settings), Settings, identity)
	var profile = service.execute(definition)
	assert_equal(profile.combined_luminosity_solar, 12.0, "component luminosities sum")
	assert_true(profile.pulse_amplitude < 0.10, "steady companion dilutes dominant pulse")
	assert_true(profile.visual_period_seconds >= 2.5 and profile.visual_period_seconds <= 8.0, "period is compressed")
	assert_true(profile.display_scale >= 0.6 and profile.display_scale <= 2.5, "display scale is bounded")
	assert_equal(service.execute(definition).as_dictionary(), profile.as_dictionary(), "combined profile is deterministic")


func _star(
	id: StringName,
	luminosity: float,
	variability: float,
	period_days: float,
	phase: float,
	spectral: StringName,
	parent := StringName()
):
	return Body.new(id, &"star", String(id), "", spectral, parent, {
		"spectral_class": spectral,
		"evolutionary_stage": &"main_sequence",
		"mass_solar": 1.0,
		"temperature_k": 5772.0 if spectral == &"G" else 4500.0,
		"radius_solar": 1.0,
		"luminosity_solar": luminosity,
		"variability_class": &"stable",
		"variability_period_days": period_days,
		"variability_fraction": variability,
		"pulse_phase": phase,
	})
