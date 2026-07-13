class_name ScientificCatalogRepository
extends RefCounted

const CatalogMetadataType = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const SystemAnchorType = preload("res://scripts/domain/catalog/system_anchor.gd")


func open() -> bool:
	return false


func close() -> void:
	pass


func metadata() -> CatalogMetadataType:
	return null


func systems_in_bounds(_bounds: Rect2) -> Array[SystemAnchorType]:
	var systems: Array[SystemAnchorType] = []
	return systems


func technical_validation_errors() -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	return findings
