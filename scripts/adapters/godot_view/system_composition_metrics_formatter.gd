class_name SystemCompositionMetricsFormatter
extends RefCounted


func format(snapshot: Dictionary) -> String:
	if not snapshot.enabled:
		return ""
	return "\n".join([
		_source_line("SS Procedural", snapshot.procedural),
		_source_line("SS Catalog", snapshot.catalog),
		_cache_line(snapshot.cache),
	])


func _source_line(label: String, source: Dictionary) -> String:
	if source.count == 0:
		return "%s: avg -- | p95 -- | max -- | n=0" % label
	return "%s: avg %.2f ms | p95 %.2f ms | max %.2f ms | n=%d" % [
		label,
		source.average_ms,
		source.p95_ms,
		source.maximum_ms,
		source.count,
	]


func _cache_line(cache: Dictionary) -> String:
	return "SS Cache: hits %d | misses %d | rate %.0f%%" % [
		cache.hits,
		cache.misses,
		cache.hit_rate * 100.0,
	]
