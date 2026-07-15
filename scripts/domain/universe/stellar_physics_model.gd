class_name StellarPhysicsModel
extends RefCounted

const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration


func complete_star_properties(
	star_id: StringName,
	visual_type: StringName,
	existing_properties: Dictionary,
	identity
) -> Dictionary:
	var result := existing_properties.duplicate(true)
	var snapshot: Dictionary = identity.configuration_snapshot()
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix_text(identity.value, "%s:stellar-physics" % star_id)
	var spectral_class: StringName = result.get(
		"spectral_class",
		_spectral_class_for_visual(visual_type, rng.randf())
	)
	if not snapshot.stellar_spectral_profiles.has(spectral_class):
		spectral_class = &"G"
	var spectral: Dictionary = snapshot.stellar_spectral_profiles[spectral_class]
	var mass: float = float(result.get(
		"mass_solar",
		rng.randf_range(float(spectral.mass_min_solar), float(spectral.mass_max_solar))
	))
	var temperature: float = float(result.get(
		"temperature_k",
		rng.randf_range(float(spectral.temperature_min_k), float(spectral.temperature_max_k))
	))
	var stage: StringName = result.get(
		"evolutionary_stage",
		_weighted_key(snapshot.stellar_evolution_stage_weights, rng)
	)
	var radius: float = float(result.get("radius_solar", _radius_for(mass, stage, rng)))
	var luminosity: float = float(result.get(
		"luminosity_solar",
		pow(radius, 2.0) * pow(temperature / 5772.0, 4.0)
	))
	var variability_class := &"stable" if stage == &"main_sequence" else &"evolved"
	variability_class = result.get("variability_class", variability_class)
	var variability: Dictionary = snapshot.stellar_variability_profiles.get(
		variability_class,
		snapshot.stellar_variability_profiles[&"stable"]
	)
	result["spectral_class"] = spectral_class
	result["evolutionary_stage"] = stage
	result["mass_solar"] = mass
	result["temperature_k"] = temperature
	result["radius_solar"] = radius
	result["luminosity_solar"] = luminosity
	result["variability_class"] = variability_class
	result["variability_period_days"] = float(result.get(
		"variability_period_days",
		rng.randf_range(float(variability.period_min_days), float(variability.period_max_days))
	))
	result["variability_fraction"] = float(result.get(
		"variability_fraction",
		rng.randf_range(float(variability.amplitude_min), float(variability.amplitude_max))
	))
	result["pulse_phase"] = float(result.get("pulse_phase", rng.randf()))
	return result


func _spectral_class_for_visual(visual_type: StringName, unit: float) -> StringName:
	match visual_type:
		&"blue":
			return &"O" if unit < 0.15 else &"B"
		&"white":
			return &"A" if unit < 0.55 else &"F"
		&"orange":
			return &"K"
		&"red":
			return &"M"
		_:
			return &"G"


func _weighted_key(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var keys := weights.keys()
	keys.sort_custom(func(left, right): return str(left) < str(right))
	var total := 0
	for key in keys:
		total += int(weights[key])
	var roll := rng.randi_range(0, maxi(total - 1, 0))
	var cumulative := 0
	for key in keys:
		cumulative += int(weights[key])
		if roll < cumulative:
			return StringName(key)
	return &"main_sequence"


func _radius_for(mass: float, stage: StringName, rng: RandomNumberGenerator) -> float:
	match stage:
		&"giant":
			return sqrt(mass) * rng.randf_range(5.0, 20.0)
		&"red_giant":
			return sqrt(mass) * rng.randf_range(20.0, 80.0)
		&"white_dwarf":
			return rng.randf_range(0.008, 0.02)
		_:
			return pow(mass, 0.8)
