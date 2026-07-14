class_name MinimapLodPolicy
extends RefCounted

const EXACT := &"exact"
const CLUSTER := &"cluster"
const DENSITY := &"density"

var settings


func _init(configuration) -> void:
	settings = configuration


func select(sector_count: int) -> StringName:
	if sector_count <= settings.minimap_exact_sector_limit:
		return EXACT
	if sector_count <= settings.minimap_cluster_sector_limit:
		return CLUSTER
	return DENSITY
