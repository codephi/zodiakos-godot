class_name UniverseGenerator
extends RefCounted

const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Star = preload("res://scripts/domain/universe/star_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const DefaultSettings = preload("res://config/game_settings.tres")


class Candidate:
	var id: StringName
	var position: Vector2
	var visual_type: StringName
	var source: StringName
	var owner
	var priority: int


var global_seed: int
var settings


func _init(seed = null, configuration = DefaultSettings) -> void:
	settings = configuration
	global_seed = settings.universe_global_seed if seed == null else seed


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
				candidate.priority,
				settings.universe_generator_version
			)
		)
		if stars.size() == settings.universe_max_stars_per_sector:
			break
	return Sector.new(
		coordinate.offset(0, 0),
		stars,
		settings.universe_generator_version
	)


func _resolve_candidates(candidates: Array) -> Array:
	var finite_candidates := candidates.filter(
		func(candidate): return _is_finite_position(candidate.position)
	)
	var accepted := []
	for candidate in finite_candidates:
		if _is_local_winner(candidate, finite_candidates):
			accepted.append(candidate)
	accepted.sort_custom(_candidate_precedes)
	return accepted


func _generate_nearby_candidates(target) -> Array:
	var result := []
	for owner_y in range(-1, 2):
		for owner_x in range(-1, 2):
			var owner = target.offset(owner_x, owner_y)
			var owner_origin: Vector2 = (
				Vector2(owner_x, owner_y) * float(settings.universe_sector_size)
			)
			_append_clusters(result, owner, owner_origin)
			_append_isolated(result, owner, owner_origin)
	return result.filter(_candidate_can_affect_target)


func _append_clusters(result: Array, owner, owner_origin: Vector2) -> void:
	var cluster_count := _rng(owner, "cluster_count").randi_range(
		settings.universe_min_clusters,
		settings.universe_max_clusters
	)
	for cluster_index in cluster_count:
		var parameters := _indexed_rng(owner, "cluster_parameters", cluster_index)
		var center := owner_origin + Vector2(
			parameters.randf_range(0.0, settings.universe_sector_size),
			parameters.randf_range(0.0, settings.universe_sector_size)
		)
		var radius := parameters.randf_range(
			settings.universe_min_cluster_radius,
			settings.universe_max_cluster_radius
		)
		var axis_ratio := parameters.randf_range(0.65, 1.0)
		var ellipse_rotation := parameters.randf_range(0.0, TAU)
		var star_count := parameters.randi_range(
			settings.universe_min_cluster_stars,
			settings.universe_max_cluster_stars
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
	var count := _rng(owner, "isolated_count").randi_range(
		0,
		settings.universe_max_isolated_stars
	)
	for star_index in count:
		var star_rng := _indexed_rng(owner, "isolated_star", star_index)
		var point := owner_origin + Vector2(
			star_rng.randf_range(0.0, settings.universe_sector_size),
			star_rng.randf_range(0.0, settings.universe_sector_size)
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
	var total_weight: int = 0
	for weight in settings.universe_visual_type_weights:
		total_weight += weight
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative_weight: int = 0
	for index in settings.universe_visual_types.size():
		cumulative_weight += settings.universe_visual_type_weights[index]
		if roll < cumulative_weight:
			return settings.universe_visual_types[index]
	return settings.universe_visual_types.back()


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
	var minimum_distance: float = settings.universe_minimum_star_distance
	var minimum_squared: float = (
		minimum_distance
		* minimum_distance
	)
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
		candidate.position.x >= -settings.universe_minimum_star_distance
		and candidate.position.y >= -settings.universe_minimum_star_distance
		and candidate.position.x < (
			settings.universe_sector_size + settings.universe_minimum_star_distance
		)
		and candidate.position.y < (
			settings.universe_sector_size + settings.universe_minimum_star_distance
		)
	)


func _inside_target(position: Vector2) -> bool:
	return (
		position.x >= 0.0
		and position.y >= 0.0
		and position.x < settings.universe_sector_size
		and position.y < settings.universe_sector_size
	)


func _is_finite_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)
