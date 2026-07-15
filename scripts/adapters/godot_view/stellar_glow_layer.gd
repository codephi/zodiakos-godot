class_name StellarGlowLayer
extends Node3D

const ShaderResource = preload("res://assets/shaders/stellar_glow.gdshader")

var settings
var multimesh_instance: MultiMeshInstance3D
var published_generation := 0


func _init(configuration) -> void:
	settings = configuration
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "StellarGlowBatch"
	add_child(multimesh_instance)
	clear()


func publish(snapshot: Dictionary) -> void:
	var transforms: Array = snapshot.get("transforms", [])
	var colors: Array = snapshot.get("colors", [])
	var custom: Array = snapshot.get("custom_data", [])
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = ShaderResource
	quad.material = material
	batch.mesh = quad
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
		batch.set_instance_color(index, colors[index])
		batch.set_instance_custom_data(index, custom[index])
	multimesh_instance.multimesh = batch
	published_generation = int(snapshot.get("generation", 0))


func clear() -> void:
	var empty := MultiMesh.new()
	empty.transform_format = MultiMesh.TRANSFORM_3D
	empty.use_colors = true
	empty.use_custom_data = true
	empty.instance_count = 0
	multimesh_instance.multimesh = empty
	published_generation = 0


func instance_count() -> int:
	return multimesh_instance.multimesh.instance_count
