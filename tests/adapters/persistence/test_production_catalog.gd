extends "res://tests/test_case.gd"

const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Validator = preload("res://scripts/application/catalog/catalog_validator.gd")
const DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"
const EXPECTED_IDS := [
	"catalog:sol",
	"catalog:sun",
	"catalog:mercury",
	"catalog:venus",
	"catalog:earth",
	"catalog:mars",
	"catalog:jupiter",
	"catalog:saturn",
	"catalog:uranus",
	"catalog:neptune",
	"catalog:moon",
	"catalog:1-ceres",
	"catalog:1p-halley",
]
const EXPECTED_ORBITS := {
	"catalog:mercury": "catalog:sun",
	"catalog:venus": "catalog:sun",
	"catalog:earth": "catalog:sun",
	"catalog:mars": "catalog:sun",
	"catalog:jupiter": "catalog:sun",
	"catalog:saturn": "catalog:sun",
	"catalog:uranus": "catalog:sun",
	"catalog:neptune": "catalog:sun",
	"catalog:moon": "catalog:earth",
	"catalog:1-ceres": "catalog:sun",
	"catalog:1p-halley": "catalog:sun",
}
const REQUIRED_SOURCE_URLS := [
	"https://science.nasa.gov/solar-system/",
	"https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1",
	"https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1P",
	"https://arxiv.org/abs/1910.03357",
	"https://arxiv.org/abs/1809.03507",
]


func run() -> void:
	_test_production_catalog_baseline()


func _test_production_catalog_baseline() -> void:
	var repository = Repository.new(DATABASE_PATH)
	assert_true(repository.open(), "production catalog opens read-only")
	if repository.get("_database") == null:
		repository.close()
		return

	var result = Validator.new().validate(repository)
	assert_true(result.is_valid(), "production catalog passes integral validation")
	assert_true(result.messages().is_empty(), "production catalog has no validation errors")
	var metadata = repository.metadata()
	assert_true(metadata != null, "production catalog has metadata")
	if metadata != null:
		assert_equal(metadata.catalog_version, 2, "production catalog version")
		assert_equal(metadata.coordinate_model_version, 1, "coordinate model version")

	var anchors = repository.systems_in_bounds(Rect2(8149.5, -0.5, 1.0, 1.0))
	var sol_count := 0
	for anchor in anchors:
		if anchor.id == &"catalog:sol":
			sol_count += 1
			assert_equal(anchor.canonical_designation, "Solar System", "Sol designation")
			assert_equal(anchor.proper_name, "Sol", "Sol proper name")
			assert_equal(
				anchor.galactocentric_position,
				Vector3(8150.0, 0.0, 20.8),
				"Sol galactocentric position"
			)
			assert_equal(anchor.map_position(), Vector2(8150.0, 0.0), "Sol map position")
	assert_equal(sol_count, 1, "bounds contain exactly one catalog:sol anchor")
	repository.close()

	var database = SQLite.new()
	database.path = DATABASE_PATH
	database.read_only = true
	database.foreign_keys = true
	database.verbosity_level = 0
	var opened: bool = database.open_db()
	assert_true(opened, "direct test connection opens")
	if not opened:
		database.close_db()
		return
	assert_true(database.read_only, "direct test connection is read-only")
	assert_true(database.foreign_keys, "direct test connection enforces foreign keys")

	_assert_scalar(database, "SELECT COUNT(*) FROM stellar_systems", 1, "system count")
	_assert_scalar(database, "SELECT COUNT(*) FROM stars", 1, "star count")
	_assert_scalar(database, "SELECT COUNT(*) FROM planets", 8, "planet count")
	_assert_scalar(database, "SELECT COUNT(*) FROM moons", 1, "moon count")
	_assert_scalar(database, "SELECT COUNT(*) FROM minor_bodies", 2, "minor-body count")
	_assert_scalar(database, "SELECT COUNT(*) FROM catalog_objects", 13, "object count")

	for object_id: String in EXPECTED_IDS:
		_assert_scalar(
			database,
			"SELECT COUNT(*) FROM catalog_objects WHERE id=?",
			1,
			"identity exists: %s" % object_id,
			[object_id]
		)
		_assert_scalar(
			database,
			"SELECT COUNT(*) FROM object_sources WHERE object_id=?",
			1,
			"identity has at least one source: %s" % object_id,
			[object_id],
			true
		)

	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM planets WHERE planet_letter IS NOT NULL",
		0,
		"Solar System planets do not invent exoplanet letters"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM planets WHERE planet_class='rocky'",
		4,
		"rocky planet count"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM planets WHERE planet_class='gas'",
		2,
		"gas planet count"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM planets WHERE planet_class='ice'",
		2,
		"ice planet count"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM stars WHERE object_id='catalog:sun' AND component='A' "
		+ "AND spectral_type='G2V'",
		1,
		"Sun component and spectral type"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM minor_bodies WHERE object_id='catalog:1-ceres' "
		+ "AND minor_body_type='dwarf_planet'",
		1,
		"Ceres subtype"
	)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM minor_bodies WHERE object_id='catalog:1p-halley' "
		+ "AND minor_body_type='comet'",
		1,
		"Halley subtype"
	)

	_assert_scalar(database, "SELECT COUNT(*) FROM orbits", 11, "orbit relationship count")
	for orbiter_id: String in EXPECTED_ORBITS:
		_assert_scalar(
			database,
			"SELECT COUNT(*) FROM orbits WHERE orbiter_id=? AND primary_object_id=?",
			1,
			"orbit relationship: %s" % orbiter_id,
			[orbiter_id, EXPECTED_ORBITS[orbiter_id]]
		)
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM orbits WHERE orbiter_id IN ('catalog:sol','catalog:sun')",
		0,
		"Sol and Sun have no local orbital rows"
	)

	for source_url: String in REQUIRED_SOURCE_URLS:
		_assert_scalar(
			database,
			"SELECT COUNT(*) FROM sources WHERE url=?",
			1,
			"required source URL: %s" % source_url,
			[source_url],
			true
		)
	database.close_db()


func _assert_scalar(
	database,
	sql: String,
	expected: int,
	message: String,
	bindings: Array = [],
	at_least: bool = false
) -> void:
	var queried: bool = database.query(sql) if bindings.is_empty() else database.query_with_bindings(
		sql,
		bindings
	)
	assert_true(queried, "%s query succeeds" % message)
	if not queried or database.query_result.is_empty():
		return
	var row: Dictionary = database.query_result[0]
	var value := int(row.values()[0])
	if at_least:
		assert_true(value >= expected, message)
	else:
		assert_equal(value, expected, message)
