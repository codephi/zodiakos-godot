class_name SQLiteCatalogFixture
extends RefCounted

const PRODUCTION_DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"
const DEFAULT_FIXTURE_PATH := "user://catalog_repository_test.sqlite"

var path: String


func _init(fixture_path: String = DEFAULT_FIXTURE_PATH) -> void:
	path = fixture_path


func prepare() -> bool:
	cleanup()
	var source_path := ProjectSettings.globalize_path(PRODUCTION_DATABASE_PATH)
	var destination_path := ProjectSettings.globalize_path(path)
	if DirAccess.copy_absolute(source_path, destination_path) != OK:
		cleanup()
		return false

	var database = SQLite.new()
	database.path = path
	database.read_only = false
	database.foreign_keys = true
	database.verbosity_level = 0
	if not database.open_db():
		database.close_db()
		cleanup()
		return false

	var transaction_started := database.query("BEGIN TRANSACTION")
	var writes_succeeded := transaction_started
	if writes_succeeded:
		writes_succeeded = database.query(
			"UPDATE catalog_metadata SET catalog_version=1"
		)
	if writes_succeeded:
		writes_succeeded = _insert_system(
			database,
			"catalog:fixture",
			"Fixture System",
			"Fixture",
			Vector3(8150.0, 0.0, 20.8)
		)
	if writes_succeeded:
		writes_succeeded = _insert_system(
			database,
			"catalog:fixture-boundary",
			"Fixture Boundary System",
			"Boundary",
			Vector3(8200.0, 0.0, 0.0)
		)
	var committed := false
	if writes_succeeded:
		committed = database.query("COMMIT")
	if transaction_started and not committed:
		database.query("ROLLBACK")
	database.close_db()
	if not committed:
		cleanup()
	return committed


func cleanup() -> void:
	var fixture_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(fixture_path):
		DirAccess.remove_absolute(fixture_path)


func _insert_system(
	database,
	object_id: String,
	designation: String,
	proper_name: String,
	position: Vector3
) -> bool:
	const OBJECT_SQL := (
		"INSERT INTO catalog_objects "
		+ "(id,object_kind,canonical_designation,proper_name) VALUES (?,?,?,?)"
	)
	const SYSTEM_SQL := (
		"INSERT INTO stellar_systems "
		+ "(object_id,galactocentric_x_pc,galactocentric_y_pc,galactocentric_z_pc) "
		+ "VALUES (?,?,?,?)"
	)
	if not database.query_with_bindings(
		OBJECT_SQL,
		[object_id, "stellar_system", designation, proper_name]
	):
		return false
	return database.query_with_bindings(
		SYSTEM_SQL,
		[object_id, position.x, position.y, position.z]
	)
