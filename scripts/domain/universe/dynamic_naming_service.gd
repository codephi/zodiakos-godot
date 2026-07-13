class_name DynamicNamingService
extends RefCounted

const MAX_STAR_INDEX := 25
const MAX_PLANET_INDEX := 24
const MAX_ROMAN_VALUE := 3999


func system_designation(global_position: Vector2, ordinal: int) -> String:
	assert(
		is_finite(global_position.x) and is_finite(global_position.y),
		"System designation coordinates must be finite"
	)
	assert(ordinal > 0, "System ordinal must be positive")
	var coordinate_x := roundi(global_position.x)
	var coordinate_y := roundi(global_position.y)
	return "ZDK-GX%s-GY%s-%02d" % [
		_format_coordinate(coordinate_x),
		_format_coordinate(coordinate_y),
		ordinal,
	]


func star_designation(system: String, index: int) -> String:
	_validate_parent_designation(system)
	assert(index >= 0 and index <= MAX_STAR_INDEX, "Star index must be 0..25")
	return "%s %s" % [system, String.chr("A".unicode_at(0) + index)]


func planet_designation(system: String, index: int) -> String:
	_validate_parent_designation(system)
	assert(index >= 0 and index <= MAX_PLANET_INDEX, "Planet index must be 0..24")
	return "%s %s" % [system, String.chr("b".unicode_at(0) + index)]


func moon_designation(planet: String, index: int) -> String:
	_validate_parent_designation(planet)
	assert(index >= 0 and index < MAX_ROMAN_VALUE, "Moon index must be 0..3998")
	return "%s-%s" % [planet, _format_roman(index + 1)]


func minor_body_designation(system: String, minor_type: StringName, index: int) -> String:
	_validate_parent_designation(system)
	assert(index >= 0, "Minor body index must be nonnegative")
	var code := _minor_body_code(minor_type)
	if code.is_empty():
		push_error("Unsupported minor body type: %s" % minor_type)
		return ""
	return "%s %s-%03d" % [system, code, index + 1]


func _validate_parent_designation(designation: String) -> void:
	assert(not designation.is_empty(), "Parent designation must not be empty")


func _format_coordinate(value: int) -> String:
	var sign_character := "+" if value >= 0 else "-"
	return "%s%06d" % [sign_character, absi(value)]


func _minor_body_code(minor_type: StringName) -> String:
	match minor_type:
		&"asteroid":
			return "SB"
		&"comet":
			return "C"
		&"dwarf_planet":
			return "DP"
		&"trans_neptunian":
			return "TNO"
		&"meteoroid":
			return "M"
		&"interstellar_object":
			return "I"
		_:
			return ""


func _format_roman(value: int) -> String:
	assert(value > 0 and value <= MAX_ROMAN_VALUE, "Roman numeral value must be 1..3999")
	var remaining := value
	var result := ""
	var values := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	for table_index in values.size():
		while remaining >= values[table_index]:
			result += symbols[table_index]
			remaining -= values[table_index]
	return result
