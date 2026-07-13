class_name StarVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")

var body: MeshInstance3D
var owner_ring: Node3D
static var shared_sphere: SphereMesh
static var materials_by_type := {}


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)
	owner_ring = Ring.new()
	owner_ring.name = "OwnerRing"
	owner_ring.visible = false
	add_child(owner_ring)


func configure(
	star_type: StringName,
	owner_color := Color(0.0, 0.0, 0.0, 0.0),
	selected := false
) -> void:
	var style := Palette.star_style(star_type)
	if shared_sphere == null:
		shared_sphere = SphereMesh.new()
		shared_sphere.radial_segments = 16
		shared_sphere.rings = 8
	if not materials_by_type.has(star_type):
		materials_by_type[star_type] = Materials.create(style.color, true, false, true)
	body.mesh = shared_sphere
	body.material_override = materials_by_type[star_type]
	scale = Vector3.ONE * float(style.scale)
	var show_ring := owner_color.a > 0.0 or selected
	if show_ring:
		owner_ring.configure(
			Palette.normalize_owner_color(owner_color),
			0.82 if selected else 0.75,
			true
		)
	else:
		owner_ring.visible = false
