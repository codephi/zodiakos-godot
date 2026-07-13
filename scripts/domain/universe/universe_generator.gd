class_name UniverseGenerator
extends RefCounted

const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Star = preload("res://scripts/domain/universe/star_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")


class Candidate:
	var id: StringName
	var position: Vector2
	var visual_type: StringName
	var source: StringName
	var owner
	var priority: int


var global_seed: int


func _init(seed := Config.GLOBAL_SEED) -> void:
	global_seed = seed


func generate_sector(coordinate: SectorCoordinate) -> UniverseSector:
	var candidates := _generate_nearby_candidates(coordinate)
	var accepted := _resolve_candidates(candidates)

	var stars := []
	for candidate in accepted:
		if not _inside_target(candidate.position):
			continue
		stars.append(
			Star.new(
				candidate.id,
				coordinate.offset(0, 0),
				candidate.position,
				candidate.visual_type,
				candidate.source,
				candidate.owner,
				candidate.priority
			)
		)
		if stars.size() == Config.MAX_STARS_PER_SECTOR:
			break
	return Sector.new(coordinate.offset(0, 0), stars)


func _resolve_candidates(candidates: Array) -> Array:
	var accepted := []
	for candidate in candidates:
		if _is_local_winner(candidate, candidates):
			accepted.append(candidate)
	accepted.sort_custom(_candidate_precedes)
	return accepted


func _generate_nearby_candidates(target) -> Array:
	var result := []
	for owner_y in range(-1, 2):
		for owner_x in range(-1, 2):
			var owner = target.offset(owner_x, owner_y)
			var owner_origin := Vector2(owner_x, owner_y) * Config.SECTOR_SIZE
			_append_clusters(result, owner, owner_origin)
			_append_isolated(result, owner, owner_origin)
	return result.filter(_candidate_can_affect_target)


func _append_clusters(result: Array, owner, owner_origin: Vector2) -> void:
	var cluster_count := _rng(owner, "cluster_count").randi_range(
		Config.MIN_CLUSTERS,
		Config.MAX_CLUSTERS
	)
	for cluster_index in cluster_count:
		var parameters := _indexed_rng(owner, "cluster_parameters", cluster_index)
		var center := owner_origin + Vector2(
			parameters.randf_range(0.0, Config.SECTOR_SIZE),
			parameters.randf_range(0.0, Config.SECTOR_SIZE)
		)
		var radius := parameters.randf_range(
			Config.MIN_CLUSTER_RADIUS,
			Config.MAX_CLUSTER_RADIUS
		)
		var axis_ratio := parameters.randf_range(0.65, 1.0)
		var ellipse_rotation := parameters.randf_range(0.0, TAU)
		var star_count := parameters.randi_range(
			Config.MIN_CLUSTER_STARS,
			Config.MAX_CLUSTER_STARS
		)
		for star_index in star_count:
			var star_rng := _indexed_rng(
				owner,
				"cluster_star",
				cluster_index,
				star_index
			)
			var distance := radius * pow(star_rng.randf(), 1.8)
			var point := Vector2.from_angle(star_rng.randf_range(0.0, TAU))
			point *= Vector2(distance, distance * axis_ratio)
			_append_candidate(
				result,
				owner,
				center + point.rotated(ellipse_rotation),
				&"cluster",
				cluster_index,
				star_index
			)


func _append_isolated(result: Array, owner, owner_origin: Vector2) -> void:
	var count := _rng(owner, "isolated_count").randi_range(0, Config.MAX_ISOLATED_STARS)
	for star_index in count:
		var star_rng := _indexed_rng(owner, "isolated_star", star_index)
		var point := owner_origin + Vector2(
			star_rng.randf_range(0.0, Config.SECTOR_SIZE),
			star_rng.randf_range(0.0, Config.SECTOR_SIZE)
		)
		_append_candidate(result, owner, point, &"isolated", -1, star_index)


func _append_candidate(
	result: Array,
	owner,
	position: Vector2,
	source: StringName,
	cluster_index: int,
	star_index: int
) -> void:
	var prefix: String
	if source == &"cluster":
		prefix = "cluster:%d:%d:%d:%d" % [owner.x, owner.y, cluster_index, star_index]
	else:
		prefix = "isolated:%d:%d:%d" % [owner.x, owner.y, star_index]

	var candidate := Candidate.new()
	candidate.id = StringName(prefix)
	candidate.position = position
	candidate.visual_type = _visual_type(owner, prefix)
	candidate.source = source
	candidate.owner = owner.offset(0, 0)
	candidate.priority = Mixer.mix(global_seed, owner, prefix)
	result.append(candidate)


func _visual_type(owner, identity: String) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, "type:" + identity)
	var roll := rng.randi_range(0, 99)
	if roll < 35:
		return &"yellow"
	if roll < 60:
		return &"red"
	if roll < 80:
		return &"white"
	if roll < 95:
		return &"orange"
	return &"blue"


func _rng(owner, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, tag)
	return rng


func _indexed_rng(
	owner,
	tag: String,
	first := -1,
	second := -1
) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, tag, first, second)
	return rng


func _is_local_winner(candidate, candidates: Array) -> bool:
	var minimum_squared := Config.MINIMUM_DISTANCE * Config.MINIMUM_DISTANCE
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


func _candidate_can_affect_target(candidate) -> bool:
	return (
		candidate.position.x >= -Config.MINIMUM_DISTANCE
		and candidate.position.y >= -Config.MINIMUM_DISTANCE
		and candidate.position.x < Config.SECTOR_SIZE + Config.MINIMUM_DISTANCE
		and candidate.position.y < Config.SECTOR_SIZE + Config.MINIMUM_DISTANCE
	)


func _inside_target(position: Vector2) -> bool:
	return (
		position.x >= 0.0
		and position.y >= 0.0
		and position.x < Config.SECTOR_SIZE
		and position.y < Config.SECTOR_SIZE
	)
