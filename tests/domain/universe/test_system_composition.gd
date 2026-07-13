extends "res://tests/test_case.gd"

const Body = preload("res://scripts/domain/universe/system_body_definition.gd")
const Orbit = preload("res://scripts/domain/universe/orbit_definition.gd")
const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")


func run() -> void:
	_test_body_contract_and_defensive_properties()
	_test_orbit_contract_preserves_optional_values()
	_test_composition_copies_and_categorizes_records()


func _test_body_contract_and_defensive_properties() -> void:
	var input_properties := {
		"spectral_type": "G2V",
		"measurements": {"temperature_k": 5772.0},
	}
	var star = Body.new(
		&"proc:test:star:0",
		&"star",
		"ZDK-X A",
		"Sol",
		&"yellow",
		&"",
		input_properties
	)

	input_properties["spectral_type"] = "changed"
	input_properties["measurements"]["temperature_k"] = 0.0
	assert_equal(star.id, &"proc:test:star:0", "body id")
	assert_equal(star.kind, &"star", "body kind")
	assert_equal(star.designation, "ZDK-X A", "body designation")
	assert_equal(star.proper_name, "Sol", "body proper name")
	assert_equal(star.subtype, &"yellow", "body subtype")
	assert_equal(star.parent_id, &"", "primary star has no parent")
	assert_equal(star.properties["spectral_type"], "G2V", "body copies input properties")
	assert_equal(
		star.properties["measurements"]["temperature_k"],
		5772.0,
		"body deep-copies nested input properties"
	)

	var exposed_properties: Dictionary = star.properties
	exposed_properties["spectral_type"] = "leaked"
	exposed_properties["measurements"]["temperature_k"] = -1.0
	assert_equal(star.properties["spectral_type"], "G2V", "body protects properties")
	assert_equal(
		star.properties["measurements"]["temperature_k"],
		5772.0,
		"body protects nested properties"
	)


func _test_orbit_contract_preserves_optional_values() -> void:
	var input_properties := {
		"semi_major_axis_au": 1.0,
		"eccentricity": null,
		"inclination_deg": 0.1,
		"orbital_period_days": 365.25,
		"longitude_ascending_node_deg": 45.0,
		"argument_periapsis_deg": 30.0,
		"elements_epoch": {"value": "J2000", "source": "catalog"},
	}
	var orbit = Orbit.new(&"proc:test:planet:0", &"proc:test:star:0", input_properties)
	var mean_anomaly_orbit = Orbit.new(
		&"proc:test:planet:1",
		&"proc:test:star:0",
		{"mean_anomaly_deg": 15.0}
	)

	input_properties["semi_major_axis_au"] = 99.0
	input_properties["elements_epoch"]["source"] = "changed"
	assert_equal(orbit.orbiter_id, &"proc:test:planet:0", "orbit orbiter id")
	assert_equal(orbit.primary_object_id, &"proc:test:star:0", "orbit primary id")
	assert_true(orbit.properties.has("eccentricity"), "orbit preserves an explicit null")
	assert_equal(orbit.properties["eccentricity"], null, "orbit preserves nullable value")
	assert_true(
		not orbit.properties.has("mean_anomaly_deg"),
		"orbit does not invent absent scientific values"
	)
	assert_equal(
		mean_anomaly_orbit.properties["mean_anomaly_deg"],
		15.0,
		"orbit recognizes mean anomaly"
	)
	assert_equal(orbit.properties["semi_major_axis_au"], 1.0, "orbit copies properties")
	assert_equal(
		orbit.properties["elements_epoch"]["source"],
		"catalog",
		"orbit deep-copies nested input properties"
	)

	var exposed_properties: Dictionary = orbit.properties
	exposed_properties["semi_major_axis_au"] = 0.0
	exposed_properties["elements_epoch"]["source"] = "leaked"
	assert_equal(orbit.properties["semi_major_axis_au"], 1.0, "orbit protects properties")
	assert_equal(
		orbit.properties["elements_epoch"]["source"],
		"catalog",
		"orbit protects nested properties"
	)


func _test_composition_copies_and_categorizes_records() -> void:
	var primary = Body.new(&"proc:test:star:0", &"star", "ZDK-X A", "", &"yellow", &"", {})
	var secondary = Body.new(
		&"proc:test:star:1",
		&"star",
		"ZDK-X B",
		"",
		&"red",
		primary.id,
		{}
	)
	var planet = Body.new(
		&"proc:test:planet:0",
		&"planet",
		"ZDK-X b",
		"",
		&"rocky",
		primary.id,
		{}
	)
	var moon = Body.new(
		&"proc:test:moon:0:0",
		&"moon",
		"ZDK-X b-I",
		"",
		&"moon",
		planet.id,
		{}
	)
	var minor = Body.new(
		&"proc:test:minor:0",
		&"minor_body",
		"ZDK-X SB-001",
		"",
		&"asteroid",
		primary.id,
		{}
	)
	var planet_orbit = Orbit.new(
		planet.id,
		primary.id,
		{"semi_major_axis_au": 1.0, "orbital_period_days": null}
	)
	var stars := [primary, secondary]
	var planets := [planet]
	var moons := [moon]
	var minor_bodies := [minor]
	var orbits := [planet_orbit]
	var composition = Composition.new(
		&"proc:test",
		stars,
		planets,
		moons,
		minor_bodies,
		orbits
	)

	stars.clear()
	planets.clear()
	moons.clear()
	minor_bodies.clear()
	orbits.clear()
	assert_equal(composition.system_id, &"proc:test", "composition system id")
	assert_equal(composition.stars.size(), 2, "constructor copies stars")
	assert_equal(
		composition.stars[1].parent_id,
		composition.stars[0].id,
		"secondary star points to the primary star"
	)
	assert_equal(composition.planets.size(), 1, "constructor copies planets")
	assert_equal(composition.moons.size(), 1, "constructor copies moons")
	assert_equal(composition.minor_bodies.size(), 1, "constructor copies minor bodies")
	assert_equal(composition.orbits.size(), 1, "constructor copies orbits")

	var exposed_stars: Array = composition.stars
	var exposed_planets: Array = composition.planets
	var exposed_moons: Array = composition.moons
	var exposed_minor_bodies: Array = composition.minor_bodies
	var exposed_orbits: Array = composition.orbits
	exposed_stars.clear()
	exposed_planets.clear()
	exposed_moons.clear()
	exposed_minor_bodies.clear()
	exposed_orbits.clear()
	assert_equal(composition.stars.size(), 2, "getter copies stars")
	assert_equal(composition.planets.size(), 1, "getter copies planets")
	assert_equal(composition.moons.size(), 1, "getter copies moons")
	assert_equal(composition.minor_bodies.size(), 1, "getter copies minor bodies")
	assert_equal(composition.orbits.size(), 1, "getter copies orbits")
