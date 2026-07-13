class_name ScientificCatalogRepository
extends RefCounted


func open() -> bool:
	return false


func close() -> void:
	pass


func metadata():
	return null


func systems_in_bounds(_bounds: Rect2) -> Array:
	return []


func technical_validation_errors() -> PackedStringArray:
	return PackedStringArray()
