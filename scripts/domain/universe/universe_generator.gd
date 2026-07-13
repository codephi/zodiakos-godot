class_name UniverseGenerator
extends RefCounted

const CandidateGenerator = preload(
	"res://scripts/domain/universe/procedural_candidate_generator.gd"
)
const DensityModel = preload("res://scripts/domain/universe/galactic_density_model.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var identity: UniverseIdentity
var settings: Resource
var metadata: CatalogMetadata

var _density_model: GalacticDensityModel
var _candidate_generator


func _init(
	catalog_repository,
	configuration: Resource = DefaultSettings,
	seed = null
) -> void:
	settings = configuration
	metadata = catalog_repository.metadata()
	if metadata == null:
		push_error("Universe generator requires valid catalog metadata")
		return
	var actual_seed: int = settings.universe_global_seed if seed == null else int(seed)
	identity = Identity.new(
		actual_seed,
		settings.universe_generator_version,
		metadata,
		settings
	)
	_density_model = DensityModel.new(settings)
	_candidate_generator = CandidateGenerator.new(
		identity,
		_density_model,
		metadata,
		settings
	)


func generate_sector(coordinate: SectorCoordinate) -> UniverseSector:
	var target_origin := _sector_origin(coordinate)
	var target_bounds := Rect2(
		target_origin,
		Vector2.ONE * settings.universe_sector_size
	)
	var accepted := _resolve_candidates(_procedural_candidates_near(coordinate, target_bounds))
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
				settings.universe_generator_version,
				0.0
			)
		)
	return Sector.new(coordinate, systems, settings.universe_generator_version)


func _procedural_candidates_near(coordinate: SectorCoordinate, target_bounds: Rect2) -> Array:
	var result := []
	var spacing: float = settings.universe_minimum_system_distance
	var expanded := target_bounds.grow(spacing)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var owner: SectorCoordinate = coordinate.offset(x, y)
			for candidate in _candidate_generator.candidates_for_owner(owner):
				if _inside_half_open(expanded, candidate.position):
					result.append(candidate)
	return result


func _resolve_candidates(candidates: Array) -> Array:
	var finite := candidates.filter(
		func(candidate): return is_finite(candidate.position.x) and is_finite(candidate.position.y)
	)
	var accepted := []
	for candidate in finite:
		if _is_local_winner(candidate, finite):
			accepted.append(candidate)
	accepted.sort_custom(_candidate_precedes)
	return accepted


func _is_local_winner(candidate, candidates: Array) -> bool:
	var spacing: float = settings.universe_minimum_system_distance
	var minimum_squared := spacing * spacing
	for other in candidates:
		if other == candidate:
			continue
		if candidate.position.distance_squared_to(other.position) >= minimum_squared:
			continue
		if _candidate_precedes(other, candidate):
			return false
	return true


func _candidate_precedes(left, right) -> bool:
	if left.priority != right.priority:
		return left.priority < right.priority
	return String(left.id) < String(right.id)


func _inside_half_open(bounds: Rect2, position: Vector2) -> bool:
	return (
		position.x >= bounds.position.x
		and position.y >= bounds.position.y
		and position.x < bounds.end.x
		and position.y < bounds.end.y
	)


func _sector_origin(coordinate: SectorCoordinate) -> Vector2:
	return Vector2(coordinate.x, coordinate.y) * settings.universe_sector_size
