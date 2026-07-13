extends "res://tests/test_case.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")


func run() -> void:
	_test_catalog_metadata_exposes_versions()
	_test_system_anchor_exposes_identity_and_position()
	_test_records_reject_public_property_mutation()
	_test_repository_port_is_inert()
	_test_repository_port_exposes_typed_domain_results()


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


func _test_records_reject_public_property_mutation() -> void:
	var metadata = Metadata.new(1, 2, 3)
	metadata.set(&"catalog_version", 99)
	assert_equal(metadata.get(&"catalog_version"), 2, "metadata rejects public mutation")

	var anchor = Anchor.new(&"catalog:sol", "Sol", "Sun", Vector3(8150.0, 0.0, 20.8))
	anchor.set(&"proper_name", "Changed")
	assert_equal(anchor.get(&"proper_name"), "Sun", "anchor rejects public mutation")


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


func _test_repository_port_exposes_typed_domain_results() -> void:
	var repository = Repository.new()
	var methods_by_name := {}
	for method in repository.get_script().get_script_method_list():
		methods_by_name[method.name] = method
	var metadata_return: Dictionary = methods_by_name.metadata.return
	var systems_return: Dictionary = methods_by_name.systems_in_bounds.return
	assert_equal(metadata_return.type, TYPE_OBJECT, "metadata return is an object contract")
	assert_equal(
		metadata_return.class_name,
		&"CatalogMetadata",
		"metadata return names the catalog domain record"
	)
	assert_equal(systems_return.type, TYPE_ARRAY, "systems return is an array contract")
	assert_equal(
		systems_return.hint_string,
		"SystemAnchor",
		"systems array names the anchor domain record"
	)
	var catalog_metadata: Metadata = repository.metadata()
	var anchors: Array[Anchor] = repository.systems_in_bounds(Rect2())
	assert_equal(catalog_metadata, null, "typed metadata remains empty in the base port")
	assert_true(anchors.is_empty(), "typed anchor result remains empty in the base port")
