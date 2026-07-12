class_name ZodiacAreaVisual
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")

var body: MeshInstance3D


func _init() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	add_child(body)


func configure(points: PackedVector3Array, color: Color) -> void:
	if points.size() < 3:
		visible = false
		return

	var indices := PackedInt32Array()
	for index in range(1, points.size() - 1):
		indices.append_array(PackedInt32Array([0, index, index + 1]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = indices

	var area_mesh := ArrayMesh.new()
	area_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var area_color := color
	area_color.a = 0.22
	body.mesh = area_mesh
	body.material_override = Materials.create(area_color, false, true, true)
	visible = true
