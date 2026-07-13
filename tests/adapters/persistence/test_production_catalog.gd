extends "res://tests/test_case.gd"

const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Validator = preload("res://scripts/application/catalog/catalog_validator.gd")
const DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"
const DATABASE_OVERRIDE_ENV := "ZODIAKOS_TEST_CATALOG_PATH"
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
const PLANET_PERIOD_DAYS := {
	"catalog:mercury": 88.0,
	"catalog:venus": 225.0,
	"catalog:earth": 365.25,
	"catalog:mars": 687.0,
	"catalog:jupiter": 4333.0,
	"catalog:saturn": 10756.0,
	"catalog:uranus": 30687.0,
	"catalog:neptune": 60190.0,
}
const SOURCE_EXPECTATIONS := [
	{
		"object_id": "catalog:sol",
		"source_id": "source:nasa-solar-system",
		"url": "https://science.nasa.gov/solar-system/",
		"roles": ["nomenclature"],
	},
	{
		"object_id": "catalog:sol",
		"source_id": "source:reid-2019",
		"url": "https://arxiv.org/abs/1910.03357",
		"roles": ["position"],
	},
	{
		"object_id": "catalog:sol",
		"source_id": "source:bennett-bovy-2019",
		"url": "https://arxiv.org/abs/1809.03507",
		"roles": ["position"],
	},
	{
		"object_id": "catalog:sun",
		"source_id": "source:nasa-sun-facts",
		"url": "https://science.nasa.gov/sun/facts/",
		"roles": ["nomenclature", "physical"],
	},
	{
		"object_id": "catalog:mercury",
		"source_id": "source:nasa-mercury-facts",
		"url": "https://science.nasa.gov/mercury/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:venus",
		"source_id": "source:nasa-venus-facts",
		"url": "https://science.nasa.gov/venus/venus-facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:earth",
		"source_id": "source:nasa-earth-facts",
		"url": "https://science.nasa.gov/earth/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:mars",
		"source_id": "source:nasa-mars-facts",
		"url": "https://science.nasa.gov/mars/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:jupiter",
		"source_id": "source:nasa-jupiter-facts",
		"url": "https://science.nasa.gov/jupiter/jupiter-facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:saturn",
		"source_id": "source:nasa-saturn-facts",
		"url": "https://science.nasa.gov/saturn/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:uranus",
		"source_id": "source:nasa-uranus-facts",
		"url": "https://science.nasa.gov/uranus/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:neptune",
		"source_id": "source:nasa-neptune-facts",
		"url": "https://science.nasa.gov/neptune/neptune-facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:moon",
		"source_id": "source:nasa-moon-facts",
		"url": "https://science.nasa.gov/moon/facts/",
		"roles": ["nomenclature", "orbit", "physical"],
	},
	{
		"object_id": "catalog:1-ceres",
		"source_id": "source:nasa-ceres-facts",
		"url": "https://science.nasa.gov/dwarf-planets/ceres/facts/",
		"roles": ["nomenclature"],
	},
	{
		"object_id": "catalog:1-ceres",
		"source_id": "source:jpl-ceres-lookup",
		"url": "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1",
		"roles": ["nomenclature"],
	},
	{
		"object_id": "catalog:1-ceres",
		"source_id": "source:jpl-ceres-api",
		"url": "https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=1&phys-par=1&full-prec=1",
		"roles": ["orbit", "physical"],
	},
	{
		"object_id": "catalog:1p-halley",
		"source_id": "source:jpl-halley-lookup",
		"url": "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1P",
		"roles": ["nomenclature"],
	},
	{
		"object_id": "catalog:1p-halley",
		"source_id": "source:jpl-halley-api",
		"url": "https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=1P&phys-par=1&full-prec=1",
		"roles": ["orbit", "physical"],
	},
]
const MINOR_BODY_BASELINES := {
	"catalog:1-ceres": {
		"radius_km": 469.7,
		"albedo": 0.090,
		"semi_major_axis_au": 2.765552595034094,
		"eccentricity": 0.07969229514816586,
		"inclination_deg": 10.58802780183462,
		"orbital_period_days": 1679.853119758983,
		"longitude_ascending_node_deg": 80.24862682043221,
		"argument_periapsis_deg": 73.29421453021587,
		"mean_anomaly_deg": 274.4193463761342,
		"elements_epoch": "JD 2461200.5 TDB",
	},
	"catalog:1p-halley": {
		"radius_km": 5.5,
		"albedo": 0.04,
		"semi_major_axis_au": 17.92863504856923,
		"eccentricity": 0.9679359956953211,
		"inclination_deg": 162.1905300439129,
		"orbital_period_days": 27728.04608790421,
		"longitude_ascending_node_deg": 59.09894720612437,
		"argument_periapsis_deg": 112.2414314637764,
		"mean_anomaly_deg": 274.3823371366792,
		"elements_epoch": "JD 2439875.5 TDB",
	},
}
const BASELINE_TOLERANCE := 0.000000001


func run() -> void:
	_test_production_catalog_baseline()


func _test_production_catalog_baseline() -> void:
	var catalog_path := _catalog_path()
	var repository = Repository.new(catalog_path)
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
	database.path = catalog_path
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

	_assert_source_associations(database)
	_assert_scientific_baseline(database)
	database.close_db()


func _catalog_path() -> String:
	var override_path := OS.get_environment(DATABASE_OVERRIDE_ENV).strip_edges()
	return DATABASE_PATH if override_path.is_empty() else override_path


func _assert_source_associations(database) -> void:
	_assert_scalar(database, "SELECT COUNT(*) FROM sources", 18, "scientific source count")
	_assert_scalar(database, "SELECT COUNT(*) FROM object_sources", 39, "source link count")
	_assert_scalar(
		database,
		"SELECT COUNT(*) FROM sources s LEFT JOIN object_sources os ON os.source_id=s.id "
		+ "WHERE os.source_id IS NULL",
		0,
		"scientific sources are not orphaned"
	)
	const ASSOCIATION_SQL := (
		"SELECT COUNT(*) FROM object_sources os JOIN sources s ON s.id=os.source_id "
		+ "WHERE os.object_id=? AND os.source_id=? AND os.source_role=? AND s.url=?"
	)
	for expectation: Dictionary in SOURCE_EXPECTATIONS:
		for role: String in expectation["roles"]:
			_assert_scalar(
				database,
				ASSOCIATION_SQL,
				1,
				"source association: %s/%s/%s"
				% [expectation["object_id"], expectation["source_id"], role],
				[
					expectation["object_id"],
					expectation["source_id"],
					role,
					expectation["url"],
				]
			)


func _assert_scientific_baseline(database) -> void:
	for planet_id: String in PLANET_PERIOD_DAYS:
		_assert_approximate_scalar(
			database,
			"SELECT orbital_period_days FROM orbits WHERE orbiter_id=?",
			PLANET_PERIOD_DAYS[planet_id],
			BASELINE_TOLERANCE,
			"planet period: %s" % planet_id,
			[planet_id]
		)
	_assert_approximate_scalar(
		database,
		"SELECT radius_km FROM moons WHERE object_id='catalog:moon'",
		1740.0,
		BASELINE_TOLERANCE,
		"Moon radius"
	)
	_assert_approximate_scalar(
		database,
		"SELECT orbital_period_days FROM orbits WHERE orbiter_id='catalog:moon'",
		27.0,
		BASELINE_TOLERANCE,
		"Moon orbital period"
	)

	var physical_fields := ["radius_km", "albedo"]
	var orbit_fields := [
		"semi_major_axis_au",
		"eccentricity",
		"inclination_deg",
		"orbital_period_days",
		"longitude_ascending_node_deg",
		"argument_periapsis_deg",
		"mean_anomaly_deg",
	]
	for object_id: String in MINOR_BODY_BASELINES:
		var baseline: Dictionary = MINOR_BODY_BASELINES[object_id]
		for field: String in physical_fields:
			_assert_approximate_scalar(
				database,
				"SELECT %s FROM minor_bodies WHERE object_id=?" % field,
				baseline[field],
				BASELINE_TOLERANCE,
				"minor body %s: %s" % [field, object_id],
				[object_id]
			)
		for field: String in orbit_fields:
			_assert_approximate_scalar(
				database,
				"SELECT %s FROM orbits WHERE orbiter_id=?" % field,
				baseline[field],
				BASELINE_TOLERANCE,
				"orbit %s: %s" % [field, object_id],
				[object_id]
			)
		_assert_text_scalar(
			database,
			"SELECT elements_epoch FROM orbits WHERE orbiter_id=?",
			baseline["elements_epoch"],
			"elements epoch: %s" % object_id,
			[object_id]
		)


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


func _assert_approximate_scalar(
	database,
	sql: String,
	expected: float,
	tolerance: float,
	message: String,
	bindings: Array = []
) -> void:
	var value = _query_scalar(database, sql, message, bindings)
	if value == null:
		return
	var difference := absf(float(value) - expected)
	assert_true(
		difference <= tolerance,
		"%s: expected %s +/- %s, got %s"
		% [message, expected, tolerance, float(value)]
	)


func _assert_text_scalar(
	database,
	sql: String,
	expected: String,
	message: String,
	bindings: Array = []
) -> void:
	var value = _query_scalar(database, sql, message, bindings)
	if value != null:
		assert_equal(String(value), expected, message)


func _query_scalar(database, sql: String, message: String, bindings: Array = []):
	var queried: bool = database.query(sql) if bindings.is_empty() else database.query_with_bindings(
		sql,
		bindings
	)
	assert_true(queried, "%s query succeeds" % message)
	if not queried:
		return null
	assert_true(not database.query_result.is_empty(), "%s returns a row" % message)
	if database.query_result.is_empty():
		return null
	var row: Dictionary = database.query_result[0]
	assert_true(not row.is_empty(), "%s returns a scalar column" % message)
	if row.is_empty():
		return null
	var value = row.values()[0]
	assert_true(value != null, "%s is not NULL" % message)
	return value
