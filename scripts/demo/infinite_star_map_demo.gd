extends Node3D

const CameraType = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")
const ViewType = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const StreamType = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")

var stats_label: Label
var map_camera
var sector_view
var stream


func _init() -> void:
	map_camera = CameraType.new()
	map_camera.name = "MapCamera"
	add_child(map_camera)

	sector_view = ViewType.new()
	sector_view.name = "SectorRoot"
	add_child(sector_view)

	stream = StreamType.new()
	stream.name = "SectorStreamController"
	add_child(stream)

	_add_environment()
	_add_hud()
	map_camera.logical_position_changed.connect(stream.update_center)
	map_camera.zoom_changed.connect(_on_zoom_changed)
	stream.stats_changed.connect(_update_stats)
	stream.configure(Generator.new(), sector_view, map_camera.logical_position)


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_stream_coverage)
	_refresh_stream_coverage()


func _add_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	world.environment = environment
	add_child(world)


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugHud"
	add_child(layer)
	stats_label = Label.new()
	stats_label.name = "Stats"
	stats_label.position = Vector2(16, 16)
	layer.add_child(stats_label)


func _update_stats(sectors: int, stars: int, center_key: String) -> void:
	stats_label.text = (
		"Seed: 0x%X\nSector: %s\nActive: %d\nStars: %d\nZoom: %.1f"
		% [Config.GLOBAL_SEED, center_key, sectors, stars, map_camera.size]
	)


func _on_zoom_changed(_new_size: float) -> void:
	_refresh_stream_coverage()
	_update_stats(
		sector_view.active_sector_count(),
		sector_view.star_count(),
		map_camera.logical_position.sector.key()
	)


func _refresh_stream_coverage() -> void:
	var viewport := get_viewport()
	if viewport == null:
		viewport = Engine.get_main_loop().root
	stream.update_view(map_camera.size, viewport.get_visible_rect().size)
