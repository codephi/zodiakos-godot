class_name SystemCollisionResolver
extends RefCounted


class Resolution:
	var anchors: Array
	var candidates: Array


	func _init(kept_anchors: Array, kept_candidates: Array) -> void:
		anchors = kept_anchors.duplicate()
		candidates = kept_candidates.duplicate()


var _minimum_distance_squared: float


func _init(minimum_distance: float) -> void:
	assert(minimum_distance > 0.0, "Collision spacing must be positive")
	_minimum_distance_squared = minimum_distance * minimum_distance


func resolve(candidates: Array, anchors: Array) -> Resolution:
	var ordered_candidates := candidates.filter(_has_finite_position).filter(
		func(candidate): return not _conflicts_with_anchor(candidate, anchors)
	)
	ordered_candidates.sort_custom(_candidate_precedes)
	var accepted := []
	for candidate in ordered_candidates:
		if not _is_local_winner(candidate, ordered_candidates):
			continue
		accepted.append(candidate)
	return Resolution.new(anchors, accepted)


func _conflicts_with_anchor(candidate, anchors: Array) -> bool:
	for anchor in anchors:
		if candidate.position.distance_squared_to(anchor.map_position()) < _minimum_distance_squared:
			return true
	return false


func _is_local_winner(candidate, candidates: Array) -> bool:
	for other in candidates:
		if other == candidate:
			continue
		if candidate.position.distance_squared_to(other.position) >= _minimum_distance_squared:
			continue
		if _candidate_precedes(other, candidate):
			return false
	return true


func _has_finite_position(candidate) -> bool:
	return is_finite(candidate.position.x) and is_finite(candidate.position.y)


func _candidate_precedes(left, right) -> bool:
	if left.priority != right.priority:
		return left.priority < right.priority
	return String(left.id) < String(right.id)
