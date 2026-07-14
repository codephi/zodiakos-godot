extends Node3D

const CameraType = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")
const ViewType = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const StreamType = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const LoadGalaxySector = preload(
	"res://scripts/application/universe/load_galaxy_sector.gd"
)
const CatalogValidatorType = preload(
	"res://scripts/application/catalog/catalog_validator.gd"
)
const CatalogRepository = preload(
	"res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd"
)
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const UniversePositionType = preload(
	"res://scripts/domain/universe/universe_position.gd"
)
const CompositionMetrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)
const CompositionMetricsFormatter = preload(
	"res://scripts/adapters/godot_view/system_composition_metrics_formatter.gd"
)
const LoadSystemComposition = preload(
	"res://scripts/application/universe/load_system_composition.gd"
)
const ProceduralSystemFactory = preload(
	"res://scripts/domain/universe/procedural_system_factory.gd"
)
const Settings = preload("res://config/game_settings.tres")

var stats_label: Label
var map_camera
var sector_view
var stream
var catalog_repository
var composition_metrics
var composition_loader
var _repository_override
var _composition_metrics_formatter


func _init(repository_override = null) -> void:
	_repository_override = repository_override
	map_camera = CameraType.new(Settings)
	map_camera.name = "MapCamera"
	add_child(map_camera)

	sector_view = ViewType.new(Settings)
	sector_view.name = "SectorRoot"
	add_child(sector_view)

	stream = StreamType.new(Settings)
	stream.name = "SectorStreamController"
	add_child(stream)

	composition_metrics = CompositionMetrics.new(
		Settings.performance_metrics_enabled,
		Settings.performance_metrics_sample_capacity
	)
	_composition_metrics_formatter = CompositionMetricsFormatter.new()
	_add_environment()
	_add_hud()
	map_camera.zoom_changed.connect(_on_zoom_changed)
	stream.stats_changed.connect(_update_stats)
	_configure_universe_stream()


func _ready() -> void:
	var viewport := get_viewport()
	if viewport == null:
		viewport = Engine.get_main_loop().root
	if not viewport.size_changed.is_connected(_refresh_stream_coverage):
		viewport.size_changed.connect(_refresh_stream_coverage)
	_refresh_stream_coverage()


func _add_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Settings.map_background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Settings.map_ambient_light_color
	environment.ambient_light_energy = Settings.map_ambient_light_energy
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


func _configure_universe_stream() -> void:
	catalog_repository = (
		_repository_override if _repository_override != null else CatalogRepository.new()
	)
	if not catalog_repository.open():
		_show_catalog_error("Could not open the scientific catalog")
		_close_catalog_repository()
		return
	var validation = CatalogValidatorType.new().validate(catalog_repository)
	if not validation.is_valid():
		_show_catalog_error(_validation_message(validation))
		_close_catalog_repository()
		return
	var generator = Generator.new(catalog_repository, Settings)
	if generator.identity == null:
		_show_catalog_error("Scientific catalog metadata is unavailable")
		_close_catalog_repository()
		return
	composition_loader = LoadSystemComposition.new(
		catalog_repository,
		ProceduralSystemFactory.new(),
		generator.identity,
		composition_metrics
	)
	var sector_source = LoadGalaxySector.new(catalog_repository, generator)
	map_camera.set_logical_position(
		UniversePositionType.new(
			Coordinate.new(203, 0),
			Vector2(30.0, 0.0),
			Settings.universe_sector_size
		)
	)
	stream.configure(sector_source, sector_view, map_camera.logical_position)
	map_camera.logical_position_changed.connect(stream.update_center)


func _show_catalog_error(message: String) -> void:
	stats_label.text = "CATALOG_INVALID: %s" % message


func _validation_message(validation) -> String:
	var findings: Array[String] = []
	var codes: Array[StringName] = validation.codes()
	var messages: Array[String] = validation.messages()
	for index in codes.size():
		findings.append("%s - %s" % [codes[index], messages[index]])
	return " | ".join(findings)


func _close_catalog_repository() -> void:
	if catalog_repository == null:
		return
	catalog_repository.close()
	catalog_repository = null


func _exit_tree() -> void:
	_close_catalog_repository()


func _update_stats(sectors: int, systems: int, center_key: String) -> void:
	var map_text := (
		"Seed: 0x%X\nSector: %s\nActive: %d\nSystems: %d\nZoom: %.1f"
		% [Settings.universe_global_seed, center_key, sectors, systems, map_camera.size]
	)
	var metrics_text: String = _composition_metrics_formatter.format(
		composition_metrics.snapshot()
	)
	stats_label.text = map_text if metrics_text.is_empty() else map_text + "\n" + metrics_text


func refresh_debug_hud() -> void:
	if stream.generator == null:
		return
	_update_stats(
		sector_view.active_sector_count(),
		sector_view.system_count(),
		map_camera.logical_position.sector.key()
	)


func _on_zoom_changed(_new_size: float) -> void:
	if stream.generator == null:
		return
	_refresh_stream_coverage()
	_update_stats(
		sector_view.active_sector_count(),
		sector_view.system_count(),
		map_camera.logical_position.sector.key()
	)


func _refresh_stream_coverage(viewport_size := Vector2.ZERO) -> void:
	if stream.generator == null:
		return
	var next_viewport_size: Vector2 = viewport_size
	if next_viewport_size == Vector2.ZERO:
		var viewport := get_viewport()
		if viewport == null:
			viewport = Engine.get_main_loop().root
		next_viewport_size = viewport.get_visible_rect().size
	stream.update_view(map_camera.size, next_viewport_size)
