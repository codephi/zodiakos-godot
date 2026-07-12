class_name ShipVisual
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
	owner_ring.position.y = -0.2
	add_child(owner_ring)


func configure(
	ship_class: StringName,
	owner_color := Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var style := Palette.ship_style(ship_class)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.8, 0.3, 1.4)
	body.mesh = prism
	body.material_override = Materials.create(style.color)
	scale = Vector3.ONE * float(style.scale)
	owner_ring.configure(Palette.normalize_owner_color(owner_color), 0.65, true)


func set_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(flat.x, flat.z)
