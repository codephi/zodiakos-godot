class_name VisualMaterialFactory
extends RefCounted

const DefaultSettings = preload("res://config/game_settings.tres")

static func create(
	color: Color,
	emission := false,
	transparent := false,
	unshaded := false,
	settings = DefaultSettings
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = emission
	material.emission = color
	if emission:
		material.emission_energy_multiplier = settings.material_emission_multiplier
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
