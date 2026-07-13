class_name ProceduralCandidateGenerator
extends RefCounted

const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")


class Candidate:
	var id: StringName
	var position: Vector2
	var visual_type: StringName
	var source: StringName = &"procedural"
	var owner:
		get:
			return _owner.offset(0, 0)
	var priority: int

	var _owner: SectorCoordinate


	func _init(
		candidate_id: StringName,
		global_position_pc: Vector2,
		type: StringName,
		owner_sector: SectorCoordinate,
		candidate_priority: int
	) -> void:
		id = candidate_id
		position = global_position_pc
		visual_type = type
		_owner = owner_sector.offset(0, 0)
		priority = candidate_priority


var identity: UniverseIdentity
var density_model: GalacticDensityModel
var metadata: CatalogMetadata
var _settings: Resource


func _init(
	universe_identity: UniverseIdentity,
	galaxy_density: GalacticDensityModel,
	catalog_metadata: CatalogMetadata,
	configuration: Resource
) -> void:
	identity = universe_identity
	density_model = galaxy_density
	metadata = catalog_metadata
	_settings = configuration


func candidates_for_owner(owner: SectorCoordinate) -> Array:
	var sector_size: float = _settings.universe_sector_size
	var origin: Vector2 = Vector2(owner.x, owner.y) * sector_size
	var center: Vector2 = origin + Vector2.ONE * sector_size * 0.5
	var raw_count: float = (
		density_model.density_at(center) * _settings.galaxy_max_candidate_systems_per_sector
	)
	var count := floori(raw_count)
	if _rng(owner, "candidate_count").randf() < raw_count - float(count):
		count += 1

	var candidates := []
	for index in count:
		var candidate_id := StringName(
			"proc:%d:%d:%d:%d:%d"
			% [
				_settings.universe_generator_version,
				metadata.catalog_version,
				owner.x,
				owner.y,
				index,
			]
		)
		var position_rng := _rng(owner, "position:%s" % candidate_id)
		var position: Vector2 = origin + Vector2(
			position_rng.randf() * sector_size,
			position_rng.randf() * sector_size
		)
		candidates.append(
			Candidate.new(
				candidate_id,
				position,
				_visual_type(owner, candidate_id),
				owner,
				Mixer.mix(identity.value, owner, "priority:%s" % candidate_id)
			)
		)
	return candidates


func _visual_type(owner: SectorCoordinate, candidate_id: StringName) -> StringName:
	var rng := _rng(owner, "visual:%s" % candidate_id)
	var total_weight := 0
	for weight: int in _settings.universe_visual_type_weights:
		total_weight += weight
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative_weight := 0
	for index in _settings.universe_visual_types.size():
		cumulative_weight += _settings.universe_visual_type_weights[index]
		if roll < cumulative_weight:
			return _settings.universe_visual_types[index]
	return _settings.universe_visual_types.back()


func _rng(owner: SectorCoordinate, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(identity.value, owner, tag)
	return rng
