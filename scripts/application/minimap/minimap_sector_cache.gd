class_name MinimapSectorCache
extends RefCounted

var capacity: int
var cache_namespace: String
var _entries := {}
var _recency: Array[String] = []


func _init(maximum_entries: int, cache_namespace: String) -> void:
	capacity = maxi(maximum_entries, 1)
	self.cache_namespace = cache_namespace


func get_sector(coordinate, generator_version: int):
	var cache_key := _key(coordinate, generator_version)
	if not _entries.has(cache_key):
		return null
	_touch(cache_key)
	return _entries[cache_key]


func put_sector(coordinate, generator_version: int, sector) -> void:
	var cache_key := _key(coordinate, generator_version)
	_entries[cache_key] = sector
	_touch(cache_key)
	while _entries.size() > capacity:
		var oldest: String = _recency.pop_front()
		_entries.erase(oldest)


func size() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
	_recency.clear()


func _touch(cache_key: String) -> void:
	_recency.erase(cache_key)
	_recency.append(cache_key)


func _key(coordinate, generator_version: int) -> String:
	return "%s:%d:%s" % [cache_namespace, generator_version, coordinate.key()]
