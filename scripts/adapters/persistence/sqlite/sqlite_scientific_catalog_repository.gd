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
