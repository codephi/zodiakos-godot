class_name UniverseGenerator
extends RefCounted

const CandidateGenerator = preload(
	"res://scripts/domain/universe/procedural_candidate_generator.gd"
)
const DensityModel = preload("res://scripts/domain/universe/galactic_density_model.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const CollisionResolver = preload(
	"res://scripts/domain/universe/system_collision_resolver.gd"
)
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var identity: UniverseIdentity
var metadata: CatalogMetadata

var _settings: Resource
var _density_model: GalacticDensityModel
var _candidate_generator


func _init(
	catalog_repository,
	configuration: Resource = DefaultSettings,
	seed = null
) -> void:
	_settings = configuration.duplicate(true)
	metadata = catalog_repository.metadata()
	if metadata == null:
		push_error("Universe generator requires valid catalog metadata")
		return
	var actual_seed: int = _settings.universe_global_seed if seed == null else int(seed)
	identity = Identity.new(
		actual_seed,
		_settings.universe_generator_version,
		metadata,
		_settings
	)
	_density_model = DensityModel.new(_settings)
	_candidate_generator = CandidateGenerator.new(
		identity,
		_density_model,
		metadata,
		_settings
	)


func generate_sector(coordinate: SectorCoordinate) -> UniverseSector:
	var target_origin := _sector_origin(coordinate)
	var target_bounds := Rect2(
		target_origin,
		Vector2.ONE * _settings.universe_sector_size
	)
	var candidates := procedural_candidates_in_bounds(
		target_bounds.grow(minimum_system_distance())
	)
	var accepted: Array = CollisionResolver.new(
		minimum_system_distance()
	).resolve(candidates, []).candidates
	var systems := []
	for candidate in accepted:
		if not _inside_half_open(target_bounds, candidate.position):
			continue
		systems.append(
			System.new(
				candidate.id,
				coordinate,
				candidate.position - target_origin,
				candidate.visual_type,
				candidate.source,
				candidate.owner,
				candidate.priority,
				_settings.universe_generator_version,
				0.0
			)
		)
	return Sector.new(coordinate, systems, _settings.universe_generator_version)


func procedural_candidates_in_bounds(bounds: Rect2) -> Array:
	if identity == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return []
	var result := []
	var size := sector_size()
	var first_x := floori(bounds.position.x / size)
	var first_y := floori(bounds.position.y / size)
	var last_x := ceili(bounds.end.x / size) - 1
	var last_y := ceili(bounds.end.y / size) - 1
	for owner_y in range(first_y, last_y + 1):
		for owner_x in range(first_x, last_x + 1):
			var owner := SectorCoordinate.new(owner_x, owner_y)
			for candidate in _candidate_generator.candidates_for_owner(owner):
				if _inside_half_open(bounds, candidate.position):
					result.append(candidate)
	return result


func sector_size() -> float:
	return _settings.universe_sector_size


func minimum_system_distance() -> float:
	return _settings.universe_minimum_system_distance


func generator_version() -> int:
	return _settings.universe_generator_version


func default_visual_type() -> StringName:
	return _settings.universe_visual_types[0]


func _inside_half_open(bounds: Rect2, position: Vector2) -> bool:
	return (
		position.x >= bounds.position.x
		and position.y >= bounds.position.y
		and position.x < bounds.end.x
		and position.y < bounds.end.y
	)


func _sector_origin(coordinate: SectorCoordinate) -> Vector2:
	return Vector2(coordinate.x, coordinate.y) * _settings.universe_sector_size
