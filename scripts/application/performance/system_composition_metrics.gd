class_name SystemCompositionMetrics
extends RefCounted

const PROCEDURAL := &"procedural"
const CATALOG := &"catalog"

var _enabled: bool
var _sample_capacity: int
var _samples := {PROCEDURAL: [], CATALOG: []}
var _failures := {PROCEDURAL: 0, CATALOG: 0}
var _cache_hits := 0
var _cache_misses := 0


func _init(enabled: bool, sample_capacity: int) -> void:
	assert(sample_capacity > 0, "Metrics sample capacity must be positive")
	_enabled = enabled
	_sample_capacity = sample_capacity


func record_success(source: StringName, duration_ms: float) -> void:
	if not _enabled or not _supports(source):
		return
	if duration_ms < 0.0 or is_nan(duration_ms) or is_inf(duration_ms):
		return
	var samples: Array = _samples[source]
	samples.append(duration_ms)
	if samples.size() > _sample_capacity:
		samples.pop_front()


func record_failure(source: StringName) -> void:
	if _enabled and _supports(source):
		_failures[source] += 1


func record_cache_hit() -> void:
	if _enabled:
		_cache_hits += 1


func record_cache_miss() -> void:
	if _enabled:
		_cache_misses += 1


func snapshot() -> Dictionary:
	var lookups := _cache_hits + _cache_misses
	return {
		"enabled": _enabled,
		"procedural": _source_snapshot(PROCEDURAL),
		"catalog": _source_snapshot(CATALOG),
		"cache": {
			"hits": _cache_hits,
			"misses": _cache_misses,
			"hit_rate": 0.0 if lookups == 0 else float(_cache_hits) / lookups,
		},
	}


func _source_snapshot(source: StringName) -> Dictionary:
	var samples: Array = _samples[source]
	if samples.is_empty():
		return {
			"count": 0,
			"average_ms": null,
			"p95_ms": null,
			"maximum_ms": null,
			"failures": _failures[source],
		}
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var total := 0.0
	for duration in samples:
		total += duration
	var p95_index := ceili(0.95 * sorted.size()) - 1
	return {
		"count": samples.size(),
		"average_ms": total / samples.size(),
		"p95_ms": sorted[p95_index],
		"maximum_ms": sorted.back(),
		"failures": _failures[source],
	}


func _supports(source: StringName) -> bool:
	return source == PROCEDURAL or source == CATALOG
