class_name CatalogMetadata
extends RefCounted

var schema_version: int:
	get:
		return _schema_version
var catalog_version: int:
	get:
		return _catalog_version
var coordinate_model_version: int:
	get:
		return _coordinate_model_version

var _schema_version: int
var _catalog_version: int
var _coordinate_model_version: int


func _init(schema: int, catalog: int, coordinates: int) -> void:
	_schema_version = schema
	_catalog_version = catalog
	_coordinate_model_version = coordinates
