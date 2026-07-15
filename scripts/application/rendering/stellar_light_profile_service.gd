class_name StellarLightProfileService
extends RefCounted

const Profile = preload("res://scripts/domain/universe/stellar_light_profile.gd")

var composition_loader
var physics_model
var settings
var identity


func _init(loader, model, configuration, universe_identity) -> void:
	composition_loader = loader
	physics_model = model
	settings = configuration
	identity = universe_identity


func execute(system_definition):
	var composition = composition_loader.execute(system_definition)
	if composition == null:
		return fallback(system_definition)
	return from_composition(system_definition, composition)


func from_composition(system_definition, composition):
	var total_luminosity := 0.0
	var weighted_color := Vector3.ZERO
	var dominant_contribution := -1.0
	var dominant_period := 1.0
	var dominant_phase := 0.0
	var dominant_class := &"stable"
	for star in composition.stars:
		var existing: Dictionary = star.properties
		if not existing.has("spectral_class") and not star.subtype.is_empty():
			existing["spectral_class"] = _spectral_letter(star.subtype)
		var properties: Dictionary = physics_model.complete_star_properties(
			star.id,
			system_definition.visual_type,
			existing,
			identity
		)
		var luminosity := maxf(float(properties.luminosity_solar), 0.000001)
		var color := _color_for_temperature(float(properties.temperature_k))
		total_luminosity += luminosity
		weighted_color += Vector3(color.r, color.g, color.b) * luminosity
		var contribution := luminosity * float(properties.variability_fraction)
		if contribution > dominant_contribution:
			dominant_contribution = contribution
			dominant_period = float(properties.variability_period_days)
			dominant_phase = float(properties.pulse_phase)
			dominant_class = properties.variability_class
	if total_luminosity <= 0.0:
		return fallback(system_definition)
	var color_vector := weighted_color / total_luminosity
	var display_scale := clampf(
		settings.stellar_glow_scale_range.x + log(1.0 + total_luminosity) * 0.35,
		settings.stellar_glow_scale_range.x,
		settings.stellar_glow_scale_range.y
	)
	var period_unit := clampf(log(1.0 + dominant_period) / log(301.0), 0.0, 1.0)
	var visual_period := lerpf(
		settings.stellar_glow_visual_period_range.x,
		settings.stellar_glow_visual_period_range.y,
		period_unit
	)
	var amplitude := dominant_contribution / total_luminosity
	if dominant_class == &"stable":
		amplitude = clampf(
			amplitude,
			settings.stellar_stable_pulse_amplitude_range.x,
			settings.stellar_stable_pulse_amplitude_range.y
		)
	else:
		amplitude = clampf(amplitude, 0.0, settings.stellar_variable_pulse_amplitude_max)
	return Profile.new(
		system_definition.id,
		Color(color_vector.x, color_vector.y, color_vector.z, 1.0),
		total_luminosity,
		display_scale,
		dominant_phase,
		visual_period,
		amplitude,
		clampf(0.25 + log(1.0 + total_luminosity) * 0.15, 0.25, 1.0)
	)


func fallback(system_definition):
	var style: Dictionary = settings.star_styles.get(
		system_definition.visual_type,
		settings.star_styles[&"yellow"]
	)
	return Profile.new(
		system_definition.id,
		style.color,
		1.0,
		clampf(float(style.scale), settings.stellar_glow_scale_range.x, settings.stellar_glow_scale_range.y),
		0.0,
		settings.stellar_glow_visual_period_range.y,
		settings.stellar_stable_pulse_amplitude_range.x,
		0.35
	)


func _spectral_letter(subtype: StringName) -> StringName:
	var text := String(subtype).strip_edges().to_upper()
	return StringName(text.left(1)) if not text.is_empty() else &"G"


func _color_for_temperature(temperature: float) -> Color:
	if temperature >= 30000.0:
		return Color(0.55, 0.70, 1.0)
	if temperature >= 10000.0:
		return Color(0.68, 0.78, 1.0)
	if temperature >= 7500.0:
		return Color(0.82, 0.88, 1.0)
	if temperature >= 6000.0:
		return Color(0.96, 0.96, 1.0)
	if temperature >= 5200.0:
		return Color(1.0, 0.90, 0.65)
	if temperature >= 3700.0:
		return Color(1.0, 0.64, 0.32)
	return Color(1.0, 0.36, 0.20)
