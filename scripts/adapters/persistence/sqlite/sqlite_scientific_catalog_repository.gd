class_name SqliteScientificCatalogRepository
extends "res://scripts/application/ports/scientific_catalog_repository.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const DEFAULT_DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"
const SYSTEMS_IN_BOUNDS_SQL := (
	"SELECT o.id,o.canonical_designation,"
	+ "COALESCE(o.proper_name,'') AS proper_name,"
	+ "s.galactocentric_x_pc,s.galactocentric_y_pc,s.galactocentric_z_pc "
	+ "FROM stellar_systems s "
	+ "JOIN catalog_objects o ON o.id=s.object_id "
	+ "WHERE s.galactocentric_x_pc>=? AND s.galactocentric_x_pc<? "
	+ "AND s.galactocentric_y_pc>=? AND s.galactocentric_y_pc<? "
	+ "ORDER BY o.id"
)
const SUBTYPE_MISMATCH_SQL := (
	"SELECT o.id FROM catalog_objects o "
	+ "LEFT JOIN stellar_systems ss ON ss.object_id=o.id "
	+ "LEFT JOIN stars st ON st.object_id=o.id "
	+ "LEFT JOIN planets p ON p.object_id=o.id "
	+ "LEFT JOIN moons m ON m.object_id=o.id "
	+ "LEFT JOIN minor_bodies mb ON mb.object_id=o.id "
	+ "WHERE (CASE WHEN ss.object_id IS NULL THEN 0 ELSE 1 END "
	+ "+ CASE WHEN st.object_id IS NULL THEN 0 ELSE 1 END "
	+ "+ CASE WHEN p.object_id IS NULL THEN 0 ELSE 1 END "
	+ "+ CASE WHEN m.object_id IS NULL THEN 0 ELSE 1 END "
	+ "+ CASE WHEN mb.object_id IS NULL THEN 0 ELSE 1 END)<>1 "
	+ "OR (o.object_kind='stellar_system' AND ss.object_id IS NULL) "
	+ "OR (o.object_kind='star' AND st.object_id IS NULL) "
	+ "OR (o.object_kind='planet' AND p.object_id IS NULL) "
	+ "OR (o.object_kind='moon' AND m.object_id IS NULL) "
	+ "OR (o.object_kind='minor_body' AND mb.object_id IS NULL) "
	+ "LIMIT 1"
)
const CROSS_SYSTEM_PARENT_SQL := (
	"WITH object_system(object_id,system_id) AS ("
	+ "SELECT object_id,object_id FROM stellar_systems "
	+ "UNION ALL SELECT object_id,system_id FROM stars "
	+ "UNION ALL SELECT object_id,system_id FROM planets "
	+ "UNION ALL SELECT object_id,system_id FROM moons "
	+ "UNION ALL SELECT object_id,system_id FROM minor_bodies"
	+ ") "
	+ "SELECT m.object_id FROM moons m "
	+ "JOIN planets p ON p.object_id=m.planet_id "
	+ "WHERE m.system_id<>p.system_id "
	+ "UNION SELECT orbit.orbiter_id FROM orbits orbit "
	+ "LEFT JOIN object_system orbiter ON orbiter.object_id=orbit.orbiter_id "
	+ "LEFT JOIN object_system primary_body ON primary_body.object_id=orbit.primary_object_id "
	+ "WHERE orbiter.system_id IS NULL OR primary_body.system_id IS NULL "
	+ "OR orbiter.system_id<>primary_body.system_id LIMIT 1"
)
const ORBIT_CYCLE_SQL := (
	"WITH RECURSIVE path(origin,current) AS ("
	+ "SELECT orbiter_id,primary_object_id FROM orbits "
	+ "UNION "
	+ "SELECT path.origin,orbit.primary_object_id FROM path "
	+ "JOIN orbits orbit ON orbit.orbiter_id=path.current"
	+ ") SELECT origin FROM path WHERE origin=current LIMIT 1"
)
const NON_FINITE_COORDINATE_SQL := (
	"SELECT object_id FROM stellar_systems WHERE "
	+ "galactocentric_x_pc IS NULL OR galactocentric_x_pc<>galactocentric_x_pc "
	+ "OR abs(galactocentric_x_pc)>=1000000000.0 "
	+ "OR galactocentric_y_pc IS NULL OR galactocentric_y_pc<>galactocentric_y_pc "
	+ "OR abs(galactocentric_y_pc)>=1000000000.0 "
	+ "OR galactocentric_z_pc IS NULL OR galactocentric_z_pc<>galactocentric_z_pc "
	+ "OR abs(galactocentric_z_pc)>=1000000000.0 LIMIT 1"
)
const DUPLICATE_DESIGNATION_SQL := (
	"SELECT lower(trim(canonical_designation)) AS normalized_designation "
	+ "FROM catalog_objects WHERE trim(canonical_designation)<>'' "
	+ "GROUP BY lower(trim(canonical_designation)) "
	+ "HAVING COUNT(*)>1 LIMIT 1"
)

var database_path: String
var _database


func _init(path: String = DEFAULT_DATABASE_PATH) -> void:
	database_path = path


func open() -> bool:
	close()
	var connection = SQLite.new()
	connection.path = database_path
	connection.read_only = true
	connection.foreign_keys = true
	connection.verbosity_level = 0
	if not connection.open_db():
		return false
	_database = connection
	return true


func close() -> void:
	if _database == null:
		return
	_database.close_db()
	_database = null


func metadata() -> Metadata:
	if _database == null:
		return null
	const SQL := (
		"SELECT schema_version,catalog_version,coordinate_model_version "
		+ "FROM catalog_metadata"
	)
	if not _database.query(SQL) or _database.query_result.size() != 1:
		return null
	var row: Dictionary = _database.query_result[0]
	return Metadata.new(
		int(row["schema_version"]),
		int(row["catalog_version"]),
		int(row["coordinate_model_version"])
	)


func systems_in_bounds(bounds: Rect2) -> Array[Anchor]:
	var systems: Array[Anchor] = []
	if _database == null:
		return systems
	var values := [
		bounds.position.x,
		bounds.end.x,
		bounds.position.y,
		bounds.end.y,
	]
	if not _database.query_with_bindings(SYSTEMS_IN_BOUNDS_SQL, values):
		return systems
	for row: Dictionary in _database.query_result:
		systems.append(_anchor_from_row(row))
	return systems


func technical_validation_errors() -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if _database == null:
		findings.append(_finding(&"CATALOG_NOT_OPEN", "Scientific catalog is not open"))
		return findings

	if not _check_integrity(findings):
		return findings
	if not _append_if_rows(
		findings,
		&"FOREIGN_KEY",
		"Catalog contains foreign key violations",
		"PRAGMA foreign_key_check"
	):
		return findings
	if not _append_if_rows(
		findings,
		&"METADATA_COUNT",
		"Catalog must contain exactly one metadata row",
		"SELECT COUNT(*) FROM catalog_metadata HAVING COUNT(*)<>1"
	):
		return findings
	if not _append_if_rows(
		findings,
		&"SUBTYPE_MISMATCH",
		"Catalog object subtype does not match its declared kind",
		SUBTYPE_MISMATCH_SQL
	):
		return findings
	if not _append_if_rows(
		findings,
		&"CROSS_SYSTEM_PARENT",
		"Catalog relationship crosses stellar system boundaries",
		CROSS_SYSTEM_PARENT_SQL
	):
		return findings
	if not _append_if_rows(
		findings,
		&"ORBIT_CYCLE",
		"Catalog orbit graph contains a cycle",
		ORBIT_CYCLE_SQL
	):
		return findings
	if not _append_if_rows(
		findings,
		&"NON_FINITE_COORDINATE",
		"Catalog system has a non-finite or out-of-range coordinate",
		NON_FINITE_COORDINATE_SQL
	):
		return findings
	if not _append_if_rows(
		findings,
		&"DUPLICATE_DESIGNATION",
		"Catalog contains duplicate normalized canonical designations",
		DUPLICATE_DESIGNATION_SQL
	):
		return findings
	return findings


func _anchor_from_row(row: Dictionary) -> Anchor:
	return Anchor.new(
		StringName(row["id"]),
		String(row["canonical_designation"]),
		String(row["proper_name"]),
		Vector3(
			float(row["galactocentric_x_pc"]),
			float(row["galactocentric_y_pc"]),
			float(row["galactocentric_z_pc"])
		)
	)


func _check_integrity(findings: Array[Dictionary]) -> bool:
	if not _database.query("PRAGMA integrity_check"):
		_append_query_failure(findings, &"SQLITE_INTEGRITY")
		return false
	if _database.query_result.is_empty():
		findings.append(_finding(&"SQLITE_INTEGRITY", "SQLite integrity check returned no result"))
		return false
	for row: Dictionary in _database.query_result:
		var values := row.values()
		if values.is_empty() or String(values[0]).to_lower() != "ok":
			findings.append(_finding(&"SQLITE_INTEGRITY", "SQLite integrity check failed"))
			return false
	return true


func _append_if_rows(
	findings: Array[Dictionary],
	code: StringName,
	message: String,
	sql: String
) -> bool:
	if not _database.query(sql):
		_append_query_failure(findings, code)
		return false
	if not _database.query_result.is_empty():
		findings.append(_finding(code, message))
	return true


func _append_query_failure(findings: Array[Dictionary], check_code: StringName) -> void:
	var message := "SQLite validation query failed for %s" % check_code
	var sqlite_error := String(_database.error_message).strip_edges()
	if not sqlite_error.is_empty():
		message += ": %s" % sqlite_error
	findings.append(_finding(&"SQLITE_QUERY", message))


func _finding(code: StringName, message: String) -> Dictionary:
	return {"code": code, "message": message}
