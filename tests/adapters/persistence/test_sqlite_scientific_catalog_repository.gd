extends "res://tests/test_case.gd"

const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Repository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Fixture = preload("res://tests/fixtures/sqlite_catalog_fixture.gd")


func run() -> void:
	_test_reads_metadata_and_bounded_systems_from_a_read_only_copy()
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
	assert_equal(anchors.size(), 1, "bounded query excludes its final x edge")
	if anchors.size() == 1:
		assert_equal(anchors[0].id, &"catalog:fixture", "anchor id is mapped")
		assert_equal(
			anchors[0].canonical_designation,
			"Fixture System",
			"anchor designation is mapped"
		)
		assert_equal(anchors[0].proper_name, "Fixture", "anchor proper name is mapped")
		assert_equal(
			anchors[0].galactocentric_position,
			Vector3(8150.0, 0.0, 20.8),
			"anchor position is mapped"
		)
		assert_equal(anchors[0].map_position(), Vector2(8150.0, 0.0), "map position is derived")

	var database = repository.get("_database")
	assert_true(database != null and database.read_only, "repository connection is read-only")
	repository.close()
	repository.close()
	fixture.cleanup()


func _test_closed_repository_returns_empty_typed_results() -> void:
	var repository = Repository.new("user://unused_catalog.sqlite")
	var catalog_metadata: Metadata = repository.metadata()
	var anchors: Array[Anchor] = repository.systems_in_bounds(Rect2())
	assert_equal(catalog_metadata, null, "closed repository has no metadata")
	assert_true(anchors.is_empty(), "closed repository has typed empty systems")
	repository.close()
