extends "res://tests/test_case.gd"

const Fixture = preload("res://tests/fixtures/sqlite_catalog_fixture.gd")
const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const ValidationResult = preload(
	"res://scripts/application/catalog/catalog_validation_result.gd"
)
const Validator = preload("res://scripts/application/catalog/catalog_validator.gd")

var _fixture_sequence := 0


func run() -> void:
	_test_validation_result_preserves_order_and_encapsulation()
	_test_valid_catalog_passes()
	_test_missing_metadata_is_explicit()
	_test_foreign_key_violation_is_explicit()
	_test_closed_catalog_stops_without_cascade()
	_test_unsupported_schema_is_explicit()
	_test_relational_and_coordinate_invariants_are_explicit()


func _test_validation_result_preserves_order_and_encapsulation() -> void:
	var result = ValidationResult.new()
	result.add(&"FIRST", "First message")
	result.add(&"SECOND", "Second message")
	assert_equal(result.codes(), [&"FIRST", &"SECOND"], "codes preserve insertion order")
	assert_equal(
		result.messages(),
		["First message", "Second message"],
		"messages preserve insertion order"
	)
	var leaked_codes: Array[StringName] = result.codes()
	var leaked_messages: Array[String] = result.messages()
	leaked_codes.clear()
	leaked_messages.clear()
	assert_equal(result.codes().size(), 2, "codes do not expose mutable storage")
	assert_equal(result.messages().size(), 2, "messages do not expose mutable storage")
	assert_true(not result.is_valid(), "a result with findings is invalid")
	assert_true(ValidationResult.new().is_valid(), "an empty result is valid")


func _test_valid_catalog_passes() -> void:
	var fixture = _new_fixture("valid")
	assert_true(fixture.prepare(), "valid fixture is prepared")
	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "valid catalog opens")
	var result = Validator.new().validate(repository)
	assert_true(result.is_valid(), "valid catalog passes")
	assert_true(result.codes().is_empty(), "valid catalog has no codes")
	repository.close()
	fixture.cleanup()


func _test_missing_metadata_is_explicit() -> void:
	var fixture = _new_fixture("missing_metadata")
	assert_true(fixture.prepare(), "missing metadata fixture is prepared")
	var database = _open_writable(fixture.path)
	assert_true(
		database.query_with_bindings("DELETE FROM catalog_metadata", []),
		"metadata is deleted"
	)
	database.close_db()

	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "missing metadata catalog opens")
	var result = Validator.new().validate(repository)
	assert_true(not result.is_valid(), "missing metadata catalog fails")
	assert_true(result.codes().has(&"METADATA_COUNT"), "metadata count failure is explicit")
	assert_true(
		_finding_codes(repository.technical_validation_errors()).has(&"METADATA_COUNT"),
		"adapter reports metadata count failure"
	)
	repository.close()
	fixture.cleanup()


func _test_relational_and_coordinate_invariants_are_explicit() -> void:
	var fixture = _new_fixture("broken_invariants")
	assert_true(fixture.prepare(), "broken invariants fixture is prepared")
	var database = _open_writable(fixture.path)
	assert_true(_write_broken_invariants(database), "broken invariants are committed")
	database.close_db()

	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "broken invariants catalog opens")
	var result = Validator.new().validate(repository)
	for expected_code: StringName in [
		&"SUBTYPE_MISMATCH",
		&"CROSS_SYSTEM_PARENT",
		&"ORBIT_CYCLE",
		&"NON_FINITE_COORDINATE",
		&"DUPLICATE_DESIGNATION",
	]:
		assert_true(result.codes().has(expected_code), "%s is explicit" % expected_code)
	repository.close()
	fixture.cleanup()


func _test_foreign_key_violation_is_explicit() -> void:
	var fixture = _new_fixture("foreign_key")
	assert_true(fixture.prepare(), "foreign key fixture is prepared")
	var database = _open_writable(fixture.path, false)
	assert_true(
		_insert_object(database, "catalog:invalid-moon", "moon", "Invalid Moon"),
		"invalid moon object is inserted"
	)
	assert_true(
		database.query_with_bindings(
			"INSERT INTO moons (object_id,system_id,planet_id) VALUES (?,?,?)",
			["catalog:invalid-moon", "catalog:fixture", "catalog:missing-planet"]
		),
		"invalid moon relation is inserted with FK enforcement disabled"
	)
	database.close_db()

	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "foreign key catalog reopens")
	var result = Validator.new().validate(repository)
	assert_true(not result.is_valid(), "foreign key violation fails validation")
	assert_true(result.codes().has(&"FOREIGN_KEY"), "foreign key failure is explicit")
	repository.close()
	fixture.cleanup()


func _test_closed_catalog_stops_without_cascade() -> void:
	var repository = Repository.new("user://catalog_validator_closed.sqlite")
	var result = Validator.new().validate(repository)
	assert_equal(result.codes(), [&"CATALOG_NOT_OPEN"], "closed catalog has one clear finding")


func _test_unsupported_schema_is_explicit() -> void:
	var fixture = _new_fixture("unsupported_schema")
	assert_true(fixture.prepare(), "unsupported schema fixture is prepared")
	var database = _open_writable(fixture.path)
	assert_true(
		database.query_with_bindings(
			"UPDATE catalog_metadata SET schema_version=?",
			[2]
		),
		"schema version is changed"
	)
	database.close_db()

	var repository = Repository.new(fixture.path)
	assert_true(repository.open(), "unsupported schema catalog opens")
	var result = Validator.new().validate(repository)
	assert_true(result.codes().has(&"SCHEMA_UNSUPPORTED"), "unsupported schema is explicit")
	repository.close()
	fixture.cleanup()


func _new_fixture(label: String) -> Fixture:
	_fixture_sequence += 1
	return Fixture.new(
		"user://catalog_validator_%s_%d.sqlite" % [label, _fixture_sequence]
	)


func _open_writable(path: String, foreign_keys: bool = true):
	var database = SQLite.new()
	database.path = path
	database.read_only = false
	database.foreign_keys = foreign_keys
	database.verbosity_level = 0
	assert_true(database.open_db(), "writable fixture database opens")
	return database


func _insert_object(
	database,
	object_id: String,
	object_kind: String,
	designation: String
) -> bool:
	return database.query_with_bindings(
		"INSERT INTO catalog_objects (id,object_kind,canonical_designation) VALUES (?,?,?)",
		[object_id, object_kind, designation]
	)


func _write_broken_invariants(database) -> bool:
	if not database.query("BEGIN TRANSACTION"):
		return false
	var succeeded := _insert_object(
		database,
		"catalog:missing-subtype",
		"minor_body",
		"Missing Subtype"
	)
	if succeeded:
		succeeded = _insert_object(
			database,
			"catalog:cross-planet",
			"planet",
			"Cross Planet"
		)
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO planets (object_id,system_id,planet_letter) VALUES (?,?,?)",
			["catalog:cross-planet", "catalog:fixture-boundary", "cross"]
		)
	if succeeded:
		succeeded = _insert_object(database, "catalog:cross-moon", "moon", "Cross Moon")
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO moons (object_id,system_id,planet_id) VALUES (?,?,?)",
			["catalog:cross-moon", "catalog:fixture", "catalog:cross-planet"]
		)
	if succeeded:
		succeeded = _insert_object(database, "catalog:cycle-star", "star", " Duplicate ")
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO stars (object_id,system_id,component) VALUES (?,?,?)",
			["catalog:cycle-star", "catalog:fixture", "validation-cycle"]
		)
	if succeeded:
		succeeded = _insert_object(database, "catalog:cycle-planet", "planet", "duplicate")
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO planets (object_id,system_id,planet_letter) VALUES (?,?,?)",
			["catalog:cycle-planet", "catalog:fixture", "cycle"]
		)
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO orbits (orbiter_id,primary_object_id) VALUES (?,?)",
			["catalog:cycle-star", "catalog:cycle-planet"]
		)
	if succeeded:
		succeeded = database.query_with_bindings(
			"INSERT INTO orbits (orbiter_id,primary_object_id) VALUES (?,?)",
			["catalog:cycle-planet", "catalog:cycle-star"]
		)
	if succeeded:
		succeeded = database.query_with_bindings(
			"UPDATE stellar_systems SET galactocentric_x_pc=? WHERE object_id=?",
			[1.0e9, "catalog:fixture-boundary"]
		)
	if succeeded and database.query("COMMIT"):
		return true
	database.query("ROLLBACK")
	return false


func _finding_codes(findings: Array[Dictionary]) -> Array[StringName]:
	var codes: Array[StringName] = []
	for finding: Dictionary in findings:
		codes.append(StringName(finding.get("code", &"")))
	return codes
