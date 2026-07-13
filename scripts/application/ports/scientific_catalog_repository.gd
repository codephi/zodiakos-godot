class_name ScientificCatalogRepository
extends RefCounted

const CatalogMetadataType = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const SystemAnchorType = preload("res://scripts/domain/catalog/system_anchor.gd")
const StellarSystemCompositionType = preload(
	"res://scripts/domain/universe/stellar_system_composition.gd"
)


func open() -> bool:
	return false


func close() -> void:
	pass


func metadata() -> CatalogMetadataType:
	return null


func systems_in_bounds(_bounds: Rect2) -> Array[SystemAnchorType]:
	var systems: Array[SystemAnchorType] = []
	return systems


func system_composition(_system_id: StringName) -> StellarSystemCompositionType:
	return null


func technical_validation_errors() -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	return findings
