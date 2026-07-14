class_name MinimapQueryService
extends RefCounted

const CacheScript = preload("res://scripts/application/minimap/minimap_sector_cache.gd")
const DensityModel = preload("res://scripts/domain/universe/galactic_density_model.gd")

var sector_source
var repository
var settings
var density_model
var cache


func _init(
	stellar_sector_source,
	scientific_repository,
	configuration,
	universe_identity,
	density_override = null
) -> void:
	sector_source = stellar_sector_source
	repository = scientific_repository
	settings = configuration
	density_model = (
		density_override if density_override != null else DensityModel.new(settings)
	)
	cache = CacheScript.new(
		settings.minimap_cache_sector_limit,
		str(universe_identity)
	)


func exact_sector(coordinate):
	var cached = cache.get_sector(coordinate, settings.universe_generator_version)
	if cached != null:
		return cached
	var sector = sector_source.generate_sector(coordinate)
	if sector != null:
		cache.put_sector(coordinate, settings.universe_generator_version, sector)
	return sector


func exact_points(coordinate) -> Array:
	var sector = exact_sector(coordinate)
	if sector == null:
		return []
	var points: Array = []
	for system in sector.systems:
		var global_position: Vector2 = (
			Vector2(system.sector.x, system.sector.y) * settings.universe_sector_size
			+ system.local_position
		)
		points.append({
			"id": system.id,
			"position": global_position,
			"visual_type": system.visual_type,
			"source": system.source,
		})
	return points


func catalog_points(bounds: Rect2) -> Array:
	var points: Array = []
	for anchor in repository.systems_in_bounds(bounds):
		points.append({
			"id": anchor.id,
			"position": anchor.map_position(),
			"visual_type": settings.universe_visual_types[0],
			"source": &"catalog",
		})
	return points


func sample_cell(
	bounds: Rect2,
	resolution: int,
	index: int,
	mode: StringName
) -> Dictionary:
	var safe_resolution := maxi(resolution, 1)
	var x := index % safe_resolution
	var y := index / safe_resolution
	var cell_size := bounds.size / float(safe_resolution)
	var cell_rect := Rect2(
		bounds.position + Vector2(x, y) * cell_size,
		cell_size
	)
	var center := cell_rect.get_center()
	var density: float = density_model.density_at(center)
	var result := {
		"rect": cell_rect,
		"position": center,
		"density": density,
	}
	if mode == &"cluster":
		var sector_area := (
			cell_rect.size.x * cell_rect.size.y
			/ pow(settings.universe_sector_size, 2.0)
		)
		result["estimated_count"] = maxi(
			roundi(
				density
				* float(settings.galaxy_max_candidate_systems_per_sector)
				* sector_area
			),
			0
		)
	return result


func cache_size() -> int:
	return cache.size()
