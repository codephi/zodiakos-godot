class_name RingVisual
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var body: MeshInstance3D
var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure(color: Color, radius := -1.0, shown := true) -> void:
	var configured_radius: float = settings.star_selected_ring_radius if radius < 0.0 else radius
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(configured_radius - settings.ring_thickness, 0.01)
	torus.outer_radius = configured_radius
	torus.rings = settings.ring_rings
	torus.ring_segments = settings.ring_segments
	body.mesh = torus
	body.material_override = Materials.create(color, true, false, true, settings)
	visible = shown
