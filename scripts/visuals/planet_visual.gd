class_name PlanetVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var body: MeshInstance3D
var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure(planet_type: StringName, size := 1.0) -> void:
	var style := Palette.planet_style(planet_type, settings)
	var sphere := SphereMesh.new()
	sphere.radial_segments = settings.planet_sphere_radial_segments
	sphere.rings = settings.planet_sphere_rings
	body.mesh = sphere
	body.material_override = Materials.create(
		style.color,
		planet_type == &"volcanic",
		false,
		false,
		settings
	)
	scale = Vector3.ONE * maxf(size, settings.planet_minimum_scale)
