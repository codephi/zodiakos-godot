class_name ConnectionSegment
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")

var body: MeshInstance3D


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure_between(
	origin: Vector3,
	destination: Vector3,
	thickness: float,
	color: Color
) -> void:
	var delta := destination - origin
	if delta.length_squared() <= 0.0001:
		visible = false
		return

	visible = true
	var box := BoxMesh.new()
	box.size = Vector3(delta.length(), thickness, thickness)
	body.mesh = box
	body.material_override = Materials.create(color, false, false, true)
	position = (origin + destination) * 0.5
	rotation.y = -atan2(delta.z, delta.x)
