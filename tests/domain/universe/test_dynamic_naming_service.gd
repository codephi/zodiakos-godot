extends "res://tests/test_case.gd"

const NamingService = preload("res://scripts/domain/universe/dynamic_naming_service.gd")


func run() -> void:
	_test_system_designations_quantize_coordinates()
	_test_stellar_and_planetary_suffixes()
	_test_minor_body_codes()
	_test_repeated_calls_are_stable()


func _test_system_designations_quantize_coordinates() -> void:
	var naming = NamingService.new()
	assert_equal(
		naming.system_designation(Vector2(8150.2, 120.4), 3),
		"ZDK-GX+008150-GY+000120-03",
		"positive coordinates"
	)
	assert_equal(
		naming.system_designation(Vector2(-12.6, -8.2), 1),
		"ZDK-GX-000013-GY-000008-01",
		"negative coordinates"
	)
	assert_equal(
		naming.system_designation(Vector2(-0.4, -0.0), 99),
		"ZDK-GX+000000-GY+000000-99",
		"rounded negative zero is normalized to positive zero"
	)
	assert_equal(
		naming.system_designation(Vector2(1000000.0, -1000000.0), 100),
		"ZDK-GX+1000000-GY-1000000-100",
		"minimum widths expand without rejecting galactic coordinates or ordinals"
	)


func _test_stellar_and_planetary_suffixes() -> void:
	var naming = NamingService.new()
	assert_equal(naming.star_designation("ZDK-X", 0), "ZDK-X A", "first star")
	assert_equal(naming.star_designation("ZDK-X", 25), "ZDK-X Z", "last star suffix")
	assert_equal(naming.planet_designation("ZDK-X", 0), "ZDK-X b", "first planet")
	assert_equal(naming.planet_designation("ZDK-X", 24), "ZDK-X z", "last planet suffix")
	assert_equal(naming.moon_designation("ZDK-X b", 0), "ZDK-X b-I", "first moon")
	assert_equal(naming.moon_designation("ZDK-X b", 1), "ZDK-X b-II", "second moon")
	assert_equal(naming.moon_designation("ZDK-X b", 48), "ZDK-X b-XLIX", "roman subtraction")
	assert_equal(
		naming.moon_designation("ZDK-X b", 3998),
		"ZDK-X b-MMMCMXCIX",
		"roman upper limit"
	)


func _test_minor_body_codes() -> void:
	var naming = NamingService.new()
	var expected := {
		&"asteroid": "SB",
		&"comet": "C",
		&"dwarf_planet": "DP",
		&"trans_neptunian": "TNO",
		&"meteoroid": "M",
		&"interstellar_object": "I",
	}
	for minor_type: StringName in expected:
		assert_equal(
			naming.minor_body_designation("ZDK-X", minor_type, 0),
			"ZDK-X %s-001" % expected[minor_type],
			"first %s" % minor_type
		)
		assert_equal(
			naming.minor_body_designation("ZDK-X", minor_type, 999),
			"ZDK-X %s-1000" % expected[minor_type],
			"minimum minor-body width expands for %s" % minor_type
		)


func _test_repeated_calls_are_stable() -> void:
	var naming = NamingService.new()
	var first := naming.system_designation(Vector2(-12.6, 120.4), 7)
	for _iteration in range(10):
		assert_equal(
			naming.system_designation(Vector2(-12.6, 120.4), 7),
			first,
			"system designation is stable across repeated calls"
		)
		assert_equal(
			naming.minor_body_designation(first, &"comet", 4),
			"%s C-005" % first,
			"minor designation is stable across repeated calls"
		)
