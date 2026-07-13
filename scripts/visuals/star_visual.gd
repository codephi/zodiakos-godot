class_name StarVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var body: MeshInstance3D
var owner_ring: Node3D
var settings
static var shared_spheres_by_settings := {}
static var materials_by_settings := {}


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)
	owner_ring = Ring.new(settings)
	owner_ring.name = "OwnerRing"
	owner_ring.visible = false
	add_child(owner_ring)


func configure(
	star_type: StringName,
	owner_color := Color(0.0, 0.0, 0.0, 0.0),
	selected := false
) -> void:
	var style := Palette.star_style(star_type, settings)
	var cache_key: int = settings.get_instance_id()
	if not shared_spheres_by_settings.has(cache_key):
		var sphere := SphereMesh.new()
		sphere.radial_segments = settings.star_sphere_radial_segments
		sphere.rings = settings.star_sphere_rings
		shared_spheres_by_settings[cache_key] = sphere
	if not materials_by_settings.has(cache_key):
		materials_by_settings[cache_key] = {}
	var material_cache: Dictionary = materials_by_settings[cache_key]
	if not material_cache.has(star_type):
		material_cache[star_type] = Materials.create(style.color, true, false, true, settings)
	body.mesh = shared_spheres_by_settings[cache_key]
	body.material_override = material_cache[star_type]
	scale = Vector3.ONE * float(style.scale)
	var show_ring := owner_color.a > 0.0 or selected
	if show_ring:
		owner_ring.configure(
			Palette.normalize_owner_color(owner_color, settings),
			settings.star_selected_ring_radius if selected else settings.star_owner_ring_radius,
			true
		)
	else:
		owner_ring.visible = false
