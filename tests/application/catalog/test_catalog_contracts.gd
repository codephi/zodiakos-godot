extends "res://tests/test_case.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")


func run() -> void:
	_test_catalog_metadata_exposes_versions()
	_test_system_anchor_exposes_identity_and_position()
	_test_repository_port_is_inert()


func _test_catalog_metadata_exposes_versions() -> void:
	var metadata = Metadata.new(1, 2, 3)
	assert_equal(metadata.schema_version, 1, "schema version is exposed")
	assert_equal(metadata.catalog_version, 2, "catalog version is exposed")
	assert_equal(metadata.coordinate_model_version, 3, "coordinate model version is exposed")


func _test_system_anchor_exposes_identity_and_position() -> void:
	var position := Vector3(8150.0, 0.0, 20.8)
	var anchor = Anchor.new(&"catalog:sol", "Sol", "Sun", position)
	assert_equal(anchor.id, &"catalog:sol", "anchor id is exposed")
	assert_equal(anchor.canonical_designation, "Sol", "canonical designation is exposed")
	assert_equal(anchor.proper_name, "Sun", "proper name is exposed")
	assert_equal(anchor.galactocentric_position, position, "galactocentric position is exposed")
	assert_equal(anchor.map_position(), Vector2(8150.0, 0.0), "anchor maps x and y")


func _test_repository_port_is_inert() -> void:
	var repository = Repository.new()
	assert_equal(repository.open(), false, "base port does not open")
	repository.close()
	assert_equal(repository.metadata(), null, "base port has no metadata")
	assert_true(repository.systems_in_bounds(Rect2()).is_empty(), "base port has no systems")
	assert_true(
		repository.technical_validation_errors().is_empty(),
		"base port has no technical validation errors"
	)
