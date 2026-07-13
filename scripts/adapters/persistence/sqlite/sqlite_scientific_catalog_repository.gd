class_name SqliteScientificCatalogRepository
extends "res://scripts/application/ports/scientific_catalog_repository.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Body = preload("res://scripts/domain/universe/system_body_definition.gd")
const Orbit = preload("res://scripts/domain/universe/orbit_definition.gd")
const Composition = preload(
	"res://scripts/domain/universe/stellar_system_composition.gd"
)
const DEFAULT_DATABASE_PATH := "res://data/catalog/zodiakos_catalog.sqlite"
const SYSTEM_EXISTS_SQL := "SELECT object_id FROM stellar_systems WHERE object_id=?"
const STARS_IN_SYSTEM_SQL := (
	"SELECT o.id,o.canonical_designation,o.proper_name,o.discovery_year,o.notes,"
	+ "s.component,s.spectral_type,s.mass_solar,s.radius_solar,"
	+ "s.temperature_k,s.luminosity_solar "
	+ "FROM stars s JOIN catalog_objects o ON o.id=s.object_id "
	+ "WHERE s.system_id=? ORDER BY o.id"
)
const PLANETS_IN_SYSTEM_SQL := (
	"SELECT o.id,o.canonical_designation,o.proper_name,o.discovery_year,o.notes,"
	+ "p.planet_letter,p.planet_class,p.mass_earth,p.radius_earth,"
	+ "p.equilibrium_temperature_k "
	+ "FROM planets p JOIN catalog_objects o ON o.id=p.object_id "
	+ "WHERE p.system_id=? ORDER BY o.id"
)
const MOONS_IN_SYSTEM_SQL := (
	"SELECT o.id,o.canonical_designation,o.proper_name,o.discovery_year,o.notes,"
	+ "m.planet_id,m.satellite_designation,m.mass_kg,m.radius_km "
	+ "FROM moons m JOIN catalog_objects o ON o.id=m.object_id "
	+ "WHERE m.system_id=? ORDER BY o.id"
)
const MINOR_BODIES_IN_SYSTEM_SQL := (
	"SELECT o.id,o.canonical_designation,o.proper_name,o.discovery_year,o.notes,"
	+ "m.minor_body_type,m.orbit_class,m.mass_kg,m.radius_km,m.albedo "
	+ "FROM minor_bodies m JOIN catalog_objects o ON o.id=m.object_id "
	+ "WHERE m.system_id=? ORDER BY o.id"
)
const ORBITS_IN_SYSTEM_SQL := (
	"SELECT r.orbiter_id,r.primary_object_id,r.semi_major_axis_au,"
	+ "r.eccentricity,r.inclination_deg,r.orbital_period_days,"
	+ "r.longitude_ascending_node_deg,r.argument_periapsis_deg,"
	+ "r.mean_anomaly_deg,r.elements_epoch "
	+ "FROM orbits r "
	+ "LEFT JOIN stars s ON s.object_id=r.orbiter_id "
	+ "LEFT JOIN planets p ON p.object_id=r.orbiter_id "
	+ "LEFT JOIN moons m ON m.object_id=r.orbiter_id "
	+ "LEFT JOIN minor_bodies b ON b.object_id=r.orbiter_id "
	+ "WHERE COALESCE(s.system_id,p.system_id,m.system_id,b.system_id)=? "
	+ "ORDER BY r.orbiter_id"
)
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


func system_composition(system_id: StringName) -> Composition:
	if _database == null or system_id.is_empty():
		return null
	var bindings := [String(system_id)]
	var system_rows = _bound_rows(SYSTEM_EXISTS_SQL, bindings)
	if system_rows == null or system_rows.size() != 1:
		return null
	var star_rows = _bound_rows(STARS_IN_SYSTEM_SQL, bindings)
	if star_rows == null:
		return null
	var planet_rows = _bound_rows(PLANETS_IN_SYSTEM_SQL, bindings)
	if planet_rows == null:
		return null
	var moon_rows = _bound_rows(MOONS_IN_SYSTEM_SQL, bindings)
	if moon_rows == null:
		return null
	var minor_body_rows = _bound_rows(MINOR_BODIES_IN_SYSTEM_SQL, bindings)
	if minor_body_rows == null:
		return null
	var orbit_rows = _bound_rows(ORBITS_IN_SYSTEM_SQL, bindings)
	if orbit_rows == null:
		return null
	return _composition_from_rows(
		system_id,
		star_rows,
		planet_rows,
		moon_rows,
		minor_body_rows,
		orbit_rows
	)


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


func _bound_rows(sql: String, bindings: Array):
	if not _database.query_with_bindings(sql, bindings):
		return null
	return _database.query_result.duplicate(true)


func _composition_from_rows(
	system_id: StringName,
	star_rows: Array,
	planet_rows: Array,
	moon_rows: Array,
	minor_body_rows: Array,
	orbit_rows: Array
) -> Composition:
	var loaded_orbit_parents: Variant = _orbit_parents(orbit_rows)
	if loaded_orbit_parents == null:
		return null
	var orbit_parents: Dictionary = loaded_orbit_parents
	var primary_star_id := _primary_star_id(star_rows, orbit_parents)
	if primary_star_id.is_empty():
		return null

	var stars: Array[Body] = []
	for row: Dictionary in star_rows:
		var body_id := StringName(row["id"])
		var parent_id: StringName = orbit_parents.get(body_id, StringName())
		if not parent_id.is_empty() and parent_id != primary_star_id:
			return null
		stars.append(
			Body.new(
				body_id,
				&"star",
				String(row["canonical_designation"]),
				_optional_text(row.get("proper_name")),
				_optional_name(row.get("spectral_type")),
				parent_id,
				_body_properties(
					row,
					[&"component", &"mass_solar", &"radius_solar", &"temperature_k", &"luminosity_solar"]
				)
			)
		)

	var planets: Array[Body] = []
	for row: Dictionary in planet_rows:
		var body_id := StringName(row["id"])
		var parent_id: StringName = orbit_parents.get(body_id, StringName())
		if parent_id.is_empty():
			return null
		planets.append(
			Body.new(
				body_id,
				&"planet",
				String(row["canonical_designation"]),
				_optional_text(row.get("proper_name")),
				_optional_name(row.get("planet_class")),
				parent_id,
				_body_properties(
					row,
					[&"planet_letter", &"mass_earth", &"radius_earth", &"equilibrium_temperature_k"]
				)
			)
		)

	var moons: Array[Body] = []
	for row: Dictionary in moon_rows:
		var body_id := StringName(row["id"])
		var parent_id := StringName(row["planet_id"])
		if orbit_parents.has(body_id) and orbit_parents[body_id] != parent_id:
			return null
		moons.append(
			Body.new(
				body_id,
				&"moon",
				String(row["canonical_designation"]),
				_optional_text(row.get("proper_name")),
				&"moon",
				parent_id,
				_body_properties(
					row,
					[&"satellite_designation", &"mass_kg", &"radius_km"]
				)
			)
		)

	var minor_bodies: Array[Body] = []
	for row: Dictionary in minor_body_rows:
		var body_id := StringName(row["id"])
		var parent_id: StringName = orbit_parents.get(body_id, StringName())
		if parent_id.is_empty():
			return null
		minor_bodies.append(
			Body.new(
				body_id,
				&"minor_body",
				String(row["canonical_designation"]),
				_optional_text(row.get("proper_name")),
				StringName(row["minor_body_type"]),
				parent_id,
				_body_properties(
					row,
					[&"orbit_class", &"mass_kg", &"radius_km", &"albedo"]
				)
			)
		)

	var orbits: Array[Orbit] = []
	for row: Dictionary in orbit_rows:
		orbits.append(
			Orbit.new(
				StringName(row["orbiter_id"]),
				StringName(row["primary_object_id"]),
				_present_properties(
					row,
					[
						&"semi_major_axis_au",
						&"eccentricity",
						&"inclination_deg",
						&"orbital_period_days",
						&"longitude_ascending_node_deg",
						&"argument_periapsis_deg",
						&"mean_anomaly_deg",
						&"elements_epoch",
					]
				)
			)
		)

	stars.sort_custom(_body_id_less)
	planets.sort_custom(_body_id_less)
	moons.sort_custom(_body_id_less)
	minor_bodies.sort_custom(_body_id_less)
	orbits.sort_custom(_orbit_id_less)
	return Composition.new(system_id, stars, planets, moons, minor_bodies, orbits)


func _orbit_parents(orbit_rows: Array):
	var parents := {}
	for row: Dictionary in orbit_rows:
		var orbiter_id := StringName(row["orbiter_id"])
		var primary_id := StringName(row["primary_object_id"])
		if orbiter_id.is_empty() or primary_id.is_empty() or parents.has(orbiter_id):
			return null
		parents[orbiter_id] = primary_id
	return parents


func _primary_star_id(star_rows: Array, orbit_parents: Dictionary) -> StringName:
	var primary_id := StringName()
	for row: Dictionary in star_rows:
		var star_id := StringName(row["id"])
		if not orbit_parents.has(star_id):
			if not primary_id.is_empty():
				return StringName()
			primary_id = star_id
	return primary_id


func _present_properties(row: Dictionary, keys: Array[StringName]) -> Dictionary:
	var properties := {}
	for key: StringName in keys:
		var column := String(key)
		if row.has(column) and row[column] != null:
			properties[column] = row[column]
	return properties


func _body_properties(row: Dictionary, subtype_keys: Array[StringName]) -> Dictionary:
	var properties := _present_properties(row, [&"discovery_year", &"notes"])
	properties.merge(_present_properties(row, subtype_keys))
	return properties


func _optional_text(value: Variant) -> String:
	return "" if value == null else String(value)


func _optional_name(value: Variant) -> StringName:
	return StringName() if value == null else StringName(value)


func _body_id_less(left: Body, right: Body) -> bool:
	return String(left.id) < String(right.id)


func _orbit_id_less(left: Orbit, right: Orbit) -> bool:
	return String(left.orbiter_id) < String(right.orbiter_id)


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
