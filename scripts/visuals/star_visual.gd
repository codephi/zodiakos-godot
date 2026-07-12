class_name StarVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")

var body: MeshInstance3D
var owner_ring: Node3D


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)
	owner_ring = Ring.new()
	owner_ring.name = "OwnerRing"
	add_child(owner_ring)


func configure(
	star_type: StringName,
	owner_color := Color(0.0, 0.0, 0.0, 0.0),
	selected := false
) -> void:
	var style := Palette.star_style(star_type)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	body.mesh = sphere
	body.material_override = Materials.create(style.color, true, false, true)
	scale = Vector3.ONE * float(style.scale)
	owner_ring.configure(
		Palette.normalize_owner_color(owner_color),
		0.82 if selected else 0.75,
		owner_color.a > 0.0 or selected
	)
