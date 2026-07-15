class_name UniverseIdentity
extends RefCounted

var value: int:
	get:
		return _value

var _value: int
var _configuration_snapshot: Dictionary


func _init(
	actual_seed: int,
	generator_version: int,
	metadata: CatalogMetadata,
	configuration: Resource
) -> void:
	assert(metadata != null, "Universe identity requires catalog metadata")
	assert(configuration != null, "Universe identity requires configuration")
	_configuration_snapshot = _take_configuration_snapshot(configuration)
	var canonical := _canonical_value(
		actual_seed,
		generator_version,
		metadata,
		_configuration_snapshot
	)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	var digest := context.finish()
	for index in range(7):
		_value = (_value << 8) | int(digest[index])
	if _value == 0:
		_value = 1


func configuration_snapshot() -> Dictionary:
	return _configuration_snapshot.duplicate(true)


func _canonical_value(
	actual_seed: int,
	generator_version: int,
	metadata: CatalogMetadata,
	settings: Dictionary
) -> String:
	var fields: Array[PackedStringArray] = [
		_pair("actual_seed", str(actual_seed)),
		_pair("generator_version", str(generator_version)),
		_pair("catalog_version", str(metadata.catalog_version)),
		_pair("coordinate_model_version", str(metadata.coordinate_model_version)),
		_pair("galaxy_disk_radius_pc", _float(settings.galaxy_disk_radius_pc)),
		_pair("galaxy_halo_radius_pc", _float(settings.galaxy_halo_radius_pc)),
		_pair("galaxy_disk_scale_length_pc", _float(settings.galaxy_disk_scale_length_pc)),
		_pair("galaxy_bulge_scale_radius_pc", _float(settings.galaxy_bulge_scale_radius_pc)),
		_pair("galaxy_bar_half_length_pc", _float(settings.galaxy_bar_half_length_pc)),
		_pair("galaxy_bar_axis_ratio", _float(settings.galaxy_bar_axis_ratio)),
		_pair("galaxy_bar_angle_deg", _float(settings.galaxy_bar_angle_deg)),
		_pair("galaxy_spiral_arm_count", str(settings.galaxy_spiral_arm_count)),
		_pair("galaxy_spiral_pitch_deg", _float(settings.galaxy_spiral_pitch_deg)),
		_pair("galaxy_spiral_arm_width_pc", _float(settings.galaxy_spiral_arm_width_pc)),
		_pair("galaxy_halo_weight", _float(settings.galaxy_halo_weight)),
		_pair(
			"galaxy_max_candidate_systems_per_sector",
			str(settings.galaxy_max_candidate_systems_per_sector)
		),
		_pair("universe_sector_size", _float(settings.universe_sector_size)),
		_pair(
			"universe_minimum_system_distance",
			_float(settings.universe_minimum_system_distance)
		),
		_pair("universe_visual_types", _string_names(settings.universe_visual_types)),
		_pair("universe_visual_type_weights", _integers(settings.universe_visual_type_weights)),
		_pair("system_min_stars", str(settings.system_min_stars)),
		_pair("system_max_stars", str(settings.system_max_stars)),
		_pair("system_max_planets", str(settings.system_max_planets)),
		_pair(
			"system_max_moons_per_planet",
			str(settings.system_max_moons_per_planet)
		),
		_pair("system_max_minor_bodies", str(settings.system_max_minor_bodies)),
		_pair("system_planet_types", _string_names(settings.system_planet_types)),
		_pair(
			"system_planet_type_weights",
			_integers(settings.system_planet_type_weights)
		),
		_pair("stellar_physics_model_version", str(settings.stellar_physics_model_version)),
		_pair("stellar_spectral_profiles", _dictionary(settings.stellar_spectral_profiles)),
		_pair("stellar_evolution_stage_weights", _dictionary(settings.stellar_evolution_stage_weights)),
		_pair("stellar_variability_profiles", _dictionary(settings.stellar_variability_profiles)),
	]
	var encoded := PackedStringArray()
	for field in fields:
		encoded.append("%d:%s%d:%s" % [field[0].length(), field[0], field[1].length(), field[1]])
	return "".join(encoded)


func _take_configuration_snapshot(configuration: Resource) -> Dictionary:
	return {
		"galaxy_disk_radius_pc": float(configuration.galaxy_disk_radius_pc),
		"galaxy_halo_radius_pc": float(configuration.galaxy_halo_radius_pc),
		"galaxy_disk_scale_length_pc": float(configuration.galaxy_disk_scale_length_pc),
		"galaxy_bulge_scale_radius_pc": float(configuration.galaxy_bulge_scale_radius_pc),
		"galaxy_bar_half_length_pc": float(configuration.galaxy_bar_half_length_pc),
		"galaxy_bar_axis_ratio": float(configuration.galaxy_bar_axis_ratio),
		"galaxy_bar_angle_deg": float(configuration.galaxy_bar_angle_deg),
		"galaxy_spiral_arm_count": int(configuration.galaxy_spiral_arm_count),
		"galaxy_spiral_pitch_deg": float(configuration.galaxy_spiral_pitch_deg),
		"galaxy_spiral_arm_width_pc": float(configuration.galaxy_spiral_arm_width_pc),
		"galaxy_halo_weight": float(configuration.galaxy_halo_weight),
		"galaxy_max_candidate_systems_per_sector": int(
			configuration.galaxy_max_candidate_systems_per_sector
		),
		"universe_sector_size": float(configuration.universe_sector_size),
		"universe_minimum_system_distance": float(
			configuration.universe_minimum_system_distance
		),
		"universe_visual_types": configuration.universe_visual_types.duplicate(),
		"universe_visual_type_weights": (
			configuration.universe_visual_type_weights.duplicate()
		),
		"system_min_stars": int(configuration.system_min_stars),
		"system_max_stars": int(configuration.system_max_stars),
		"system_max_planets": int(configuration.system_max_planets),
		"system_max_moons_per_planet": int(configuration.system_max_moons_per_planet),
		"system_max_minor_bodies": int(configuration.system_max_minor_bodies),
		"system_planet_types": configuration.system_planet_types.duplicate(),
		"system_planet_type_weights": configuration.system_planet_type_weights.duplicate(),
		"stellar_physics_model_version": int(configuration.stellar_physics_model_version),
		"stellar_spectral_profiles": configuration.stellar_spectral_profiles.duplicate(true),
		"stellar_evolution_stage_weights": configuration.stellar_evolution_stage_weights.duplicate(true),
		"stellar_variability_profiles": configuration.stellar_variability_profiles.duplicate(true),
	}


func _pair(key: String, field_value: String) -> PackedStringArray:
	return PackedStringArray([key, field_value])


func _float(number: float) -> String:
	return String.num(number, 17)


func _string_names(values: Array[StringName]) -> String:
	var encoded := PackedStringArray()
	for item in values:
		var text := String(item)
		encoded.append("%d:%s" % [text.length(), text])
	return "".join(encoded)


func _integers(values: Array[int]) -> String:
	var encoded := PackedStringArray()
	for item in values:
		var text := str(item)
		encoded.append("%d:%s" % [text.length(), text])
	return "".join(encoded)


func _dictionary(value: Dictionary) -> String:
	var keys := value.keys()
	keys.sort_custom(func(left, right): return str(left) < str(right))
	var encoded := PackedStringArray()
	for key in keys:
		var item = value[key]
		var item_text := _dictionary(item) if item is Dictionary else str(item)
		encoded.append("%s=%s" % [str(key), item_text])
	return "{" + ",".join(encoded) + "}"
