class_name PlanetVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")

var body: MeshInstance3D


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure(planet_type: StringName, size := 1.0) -> void:
	var style := Palette.planet_style(planet_type)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	body.mesh = sphere
	body.material_override = Materials.create(style.color, planet_type == &"volcanic")
	scale = Vector3.ONE * maxf(size, 0.1)
