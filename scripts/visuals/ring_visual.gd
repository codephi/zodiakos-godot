class_name RingVisual
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")

var body: MeshInstance3D


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure(color: Color, radius := 0.8, shown := true) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - 0.04, 0.01)
	torus.outer_radius = radius
	torus.rings = 16
	torus.ring_segments = 6
	body.mesh = torus
	body.material_override = Materials.create(color, true, false, true)
	visible = shown
