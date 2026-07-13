class_name ShipVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var body: MeshInstance3D
var owner_ring: Node3D
var settings


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)
	owner_ring = Ring.new(settings)
	owner_ring.name = "OwnerRing"
	owner_ring.position.y = settings.ship_owner_ring_height
	add_child(owner_ring)


func configure(
	ship_class: StringName,
	owner_color := Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var style := Palette.ship_style(ship_class, settings)
	var prism := PrismMesh.new()
	prism.size = settings.ship_prism_size
	body.mesh = prism
	body.material_override = Materials.create(style.color, false, false, false, settings)
	scale = Vector3.ONE * float(style.scale)
	owner_ring.configure(
		Palette.normalize_owner_color(owner_color, settings),
		settings.ship_owner_ring_radius,
		true
	)


func set_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(flat.x, flat.z)
