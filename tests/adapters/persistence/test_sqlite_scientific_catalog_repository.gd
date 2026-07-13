extends "res://tests/test_case.gd"

const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Composition = preload(
	"res://scripts/domain/universe/stellar_system_composition.gd"
)
const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Fixture = preload("res://tests/fixtures/sqlite_catalog_fixture.gd")
const PRODUCTION_DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"


class FailingCompositionDatabase:
	extends RefCounted

	var query_result: Array[Dictionary] = []
	var error_message := ""
	var bindings_history: Array[Array] = []


	func query_with_bindings(_sql: String, bindings: Array) -> bool:
		bindings_history.append(bindings.duplicate())
		match bindings_history.size():
			1:
				query_result = [{"object_id": "catalog:sol"}]
				return true
			2:
				query_result = []
				return true
			_:
				error_message = "forced composition query failure"
				return false


func run() -> void:
	_test_reads_metadata_and_bounded_systems_from_a_read_only_copy()
	_test_loads_complete_catalog_composition_without_inventing_values()
	_test_unknown_system_and_query_failure_return_no_partial_composition()
	_test_closed_repository_returns_empty_typed_results()


func _test_reads_metadata_and_bounded_systems_from_a_read_only_copy() -> void:
	var fixture = Fixture.new()
	assert_true(fixture.prepare(), "SQLite catalog fixture is prepared")
	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "repository opens fixture")

	var catalog_metadata: Metadata = repository.metadata()
	assert_true(catalog_metadata != null, "repository maps catalog metadata")
	if catalog_metadata != null:
		assert_equal(catalog_metadata.schema_version, 1, "schema version")
		assert_equal(catalog_metadata.catalog_version, 1, "catalog version")
		assert_equal(catalog_metadata.coordinate_model_version, 1, "coordinate model version")

	var anchors: Array[Anchor] = repository.systems_in_bounds(
		Rect2(8100.0, -50.0, 100.0, 100.0)
	)
	var anchors_by_id := {}
	for anchor: Anchor in anchors:
		anchors_by_id[anchor.id] = anchor
	assert_true(anchors_by_id.has(&"catalog:fixture"), "fixture anchor is returned")
	assert_true(
		not anchors_by_id.has(&"catalog:fixture-boundary"),
		"bounded query excludes its final x edge"
	)
	var fixture_anchor: Anchor = anchors_by_id.get(&"catalog:fixture") as Anchor
	if fixture_anchor != null:
		assert_equal(fixture_anchor.id, &"catalog:fixture", "anchor id is mapped")
		assert_equal(
			fixture_anchor.canonical_designation,
			"Fixture System",
			"anchor designation is mapped"
		)
		assert_equal(fixture_anchor.proper_name, "Fixture", "anchor proper name is mapped")
		assert_equal(
			fixture_anchor.galactocentric_position,
			Vector3(8150.0, 0.0, 20.8),
			"anchor position is mapped"
		)
		assert_equal(
			fixture_anchor.map_position(),
			Vector2(8150.0, 0.0),
			"map position is derived"
		)

	var database = repository.get("_database")
	assert_true(database != null and database.read_only, "repository connection is read-only")
	repository.close()
	repository.close()
	fixture.cleanup()


func _test_closed_repository_returns_empty_typed_results() -> void:
	var repository = Repository.new("user://unused_catalog.sqlite")
	var catalog_metadata: Metadata = repository.metadata()
	var anchors: Array[Anchor] = repository.systems_in_bounds(Rect2())
	var composition: Composition = repository.system_composition(&"catalog:sol")
	assert_equal(catalog_metadata, null, "closed repository has no metadata")
	assert_true(anchors.is_empty(), "closed repository has typed empty systems")
	assert_equal(composition, null, "closed repository has no system composition")
	repository.close()


func _test_loads_complete_catalog_composition_without_inventing_values() -> void:
	var repository = Repository.new(PRODUCTION_DATABASE_PATH)
	assert_true(repository.open(), "repository opens production catalog for composition")
	var composition: Composition = repository.system_composition(&"catalog:sol")
	assert_true(composition != null, "repository loads the Solar System composition")
	if composition == null:
		repository.close()
		return

	assert_equal(composition.system_id, &"catalog:sol", "composition retains system id")
	assert_equal(composition.stars.size(), 1, "Solar System has its catalog star")
	assert_equal(composition.planets.size(), 8, "Solar System has its catalog planets")
	assert_equal(composition.moons.size(), 1, "Solar System has its catalog moon")
	assert_equal(composition.minor_bodies.size(), 2, "Solar System has catalog minor bodies")
	assert_equal(composition.orbits.size(), 11, "Solar System has every catalog orbit")
	_assert_sorted_by_id(composition.stars, "stars are sorted by id")
	_assert_sorted_by_id(composition.planets, "planets are sorted by id")
	_assert_sorted_by_id(composition.moons, "moons are sorted by id")
	_assert_sorted_by_id(composition.minor_bodies, "minor bodies are sorted by id")

	var all_bodies := (
		composition.stars
		+ composition.planets
		+ composition.moons
		+ composition.minor_bodies
	)
	_assert_body_ids_exist_in_sqlite(repository.get("_database"), all_bodies)
	for body in all_bodies:
		assert_true(not String(body.id).begins_with("proc:"), "catalog body id is not procedural")

	var sun = _find_body(composition.stars, &"catalog:sun")
	assert_true(sun != null, "Sun is loaded")
	if sun != null:
		assert_equal(sun.designation, "Sun", "Sun canonical designation is preserved")
		assert_equal(sun.proper_name, "Sun", "Sun proper name is preserved")
		assert_equal(sun.subtype, &"G2V", "Sun spectral subtype is preserved")
		assert_equal(sun.parent_id, StringName(), "Sun is the primary star")
		assert_equal(sun.properties.get("component"), "A", "Sun component is preserved")

	var earth = _find_body(composition.planets, &"catalog:earth")
	assert_true(earth != null, "Earth is loaded")
	if earth != null:
		assert_equal(earth.designation, "Earth", "Earth designation is preserved")
		assert_equal(earth.subtype, &"rocky", "Earth planet subtype is preserved")
		assert_equal(earth.parent_id, &"catalog:sun", "Earth orbits the Sun")
		assert_true(
			not earth.properties.has("planet_letter"),
			"Earth does not receive an invented planet letter"
		)

	var moon = _find_body(composition.moons, &"catalog:moon")
	assert_true(moon != null, "Moon is loaded")
	if moon != null:
		assert_equal(moon.parent_id, &"catalog:earth", "Moon parent is Earth")
		assert_equal(moon.properties.get("radius_km"), 1740.0, "Moon radius is preserved")

	var ceres = _find_body(composition.minor_bodies, &"catalog:1-ceres")
	assert_true(ceres != null, "Ceres is loaded")
	if ceres != null:
		assert_equal(ceres.kind, &"minor_body", "Ceres is a minor body")
		assert_equal(ceres.subtype, &"dwarf_planet", "Ceres subtype is preserved")
		assert_equal(ceres.parent_id, &"catalog:sun", "Ceres orbits the Sun")
		assert_equal(ceres.properties.get("discovery_year"), 1801, "Ceres discovery year")

	var moon_orbit = _find_orbit(composition.orbits, &"catalog:moon")
	assert_true(moon_orbit != null, "Moon orbit is loaded")
	if moon_orbit != null:
		assert_equal(moon_orbit.primary_object_id, &"catalog:earth", "Moon orbit primary")
		assert_true(
			not moon_orbit.properties.has("mean_anomaly_deg"),
			"nullable orbit values remain absent"
		)
	repository.close()


func _test_unknown_system_and_query_failure_return_no_partial_composition() -> void:
	var repository = Repository.new(PRODUCTION_DATABASE_PATH)
	assert_true(repository.open(), "repository opens for unknown system lookup")
	var unknown: Composition = repository.system_composition(&"catalog:unknown")
	assert_equal(unknown, null, "unknown catalog system has no composition")
	repository.close()

	var failing_database := FailingCompositionDatabase.new()
	var failing_repository = Repository.new("user://unused_catalog.sqlite")
	failing_repository.set("_database", failing_database)
	var partial: Composition = failing_repository.system_composition(&"catalog:sol")
	assert_equal(partial, null, "query failure returns no partial composition")
	assert_equal(
		failing_database.error_message,
		"forced composition query failure",
		"SQLite error remains available to the caller"
	)
	assert_equal(failing_database.bindings_history.size(), 3, "loader stops at first query failure")
	for bindings: Array in failing_database.bindings_history:
		assert_equal(bindings, ["catalog:sol"], "composition query binds the system id")


func _assert_body_ids_exist_in_sqlite(database, bodies: Array) -> void:
	const SQL := "SELECT COUNT(*) AS object_count FROM catalog_objects WHERE id=?"
	for body in bodies:
		var queried: bool = database.query_with_bindings(SQL, [String(body.id)])
		assert_true(queried, "body identity lookup succeeds: %s" % body.id)
		if queried and not database.query_result.is_empty():
			assert_equal(
				int(database.query_result[0]["object_count"]),
				1,
				"body identity exists in SQLite: %s" % body.id
			)


func _assert_sorted_by_id(bodies: Array, message: String) -> void:
	var ids: Array[String] = []
	for body in bodies:
		ids.append(String(body.id))
	var expected := ids.duplicate()
	expected.sort()
	assert_equal(ids, expected, message)


func _find_body(bodies: Array, body_id: StringName):
	for body in bodies:
		if body.id == body_id:
			return body
	return null


func _find_orbit(orbits: Array, orbiter_id: StringName):
	for orbit in orbits:
		if orbit.orbiter_id == orbiter_id:
			return orbit
	return null
