class_name UniverseIdentity
extends RefCounted

var value: int:
	get:
		return _value

var _value: int


func _init(
	actual_seed: int,
	generator_version: int,
	metadata: CatalogMetadata,
	configuration: Resource
) -> void:
	assert(metadata != null, "Universe identity requires catalog metadata")
	var canonical := _canonical_value(
		actual_seed,
		generator_version,
		metadata,
		configuration
	)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	var digest := context.finish()
	for index in range(7):
		_value = (_value << 8) | int(digest[index])
	if _value == 0:
		_value = 1


func _canonical_value(
	actual_seed: int,
	generator_version: int,
	metadata: CatalogMetadata,
	settings: Resource
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
	]
	var encoded := PackedStringArray()
	for field in fields:
		encoded.append("%d:%s%d:%s" % [field[0].length(), field[0], field[1].length(), field[1]])
	return "".join(encoded)


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
