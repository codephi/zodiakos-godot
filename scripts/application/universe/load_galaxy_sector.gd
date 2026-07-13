class_name LoadGalaxySector
extends RefCounted

const CollisionResolver = preload(
	"res://scripts/domain/universe/system_collision_resolver.gd"
)
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")

var _repository
var _generator
var _sector_size: float
var _minimum_distance: float
var _generator_version: int
var _default_visual_type: StringName
var _resolver


func _init(catalog_repository, procedural_generator) -> void:
	_repository = catalog_repository
	_generator = procedural_generator
	_sector_size = procedural_generator.sector_size()
	_minimum_distance = procedural_generator.minimum_system_distance()
	_generator_version = procedural_generator.generator_version()
	_default_visual_type = procedural_generator.default_visual_type()
	_resolver = CollisionResolver.new(_minimum_distance)


func generate_sector(coordinate: SectorCoordinate) -> UniverseSector:
	var target_origin := _sector_origin(coordinate)
	var target_bounds := Rect2(target_origin, Vector2.ONE * _sector_size)
	var candidate_bounds := target_bounds.grow(_minimum_distance)
	var anchor_bounds := candidate_bounds.grow(_minimum_distance)
	var anchors: Array = _repository.systems_in_bounds(anchor_bounds)
	var candidates: Array = _generator.procedural_candidates_in_bounds(candidate_bounds)
	var resolution = _resolver.resolve(candidates, anchors)
	var systems := []
	for anchor in resolution.anchors:
		var position: Vector2 = anchor.map_position()
		if _inside_half_open(target_bounds, position):
			systems.append(_catalog_system(anchor, coordinate, target_origin))
	for candidate in resolution.candidates:
		if _inside_half_open(target_bounds, candidate.position):
			systems.append(_procedural_system(candidate, coordinate, target_origin))
	return Sector.new(coordinate, systems, _generator_version)


func _catalog_system(anchor, coordinate: SectorCoordinate, target_origin: Vector2):
	return System.new(
		anchor.id,
		coordinate,
		anchor.map_position() - target_origin,
		_default_visual_type,
		&"catalog",
		coordinate,
		-1,
		_generator_version,
		anchor.galactocentric_position.z
	)


func _procedural_system(candidate, coordinate: SectorCoordinate, target_origin: Vector2):
	return System.new(
		candidate.id,
		coordinate,
		candidate.position - target_origin,
		candidate.visual_type,
		&"procedural",
		candidate.owner,
		candidate.priority,
		_generator_version,
		0.0
	)


func _inside_half_open(bounds: Rect2, position: Vector2) -> bool:
	return (
		position.x >= bounds.position.x
		and position.y >= bounds.position.y
		and position.x < bounds.end.x
		and position.y < bounds.end.y
	)


func _sector_origin(coordinate: SectorCoordinate) -> Vector2:
	return Vector2(coordinate.x, coordinate.y) * _sector_size
