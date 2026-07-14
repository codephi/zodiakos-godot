extends "res://tests/test_case.gd"

const CacheScript = preload("res://scripts/application/minimap/minimap_sector_cache.gd")
const QueryService = preload("res://scripts/application/minimap/minimap_query_service.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Settings = preload("res://config/game_settings.tres")


class FakeSectorSource:
	var calls := {}


	func generate_sector(coordinate):
		calls[coordinate.key()] = calls.get(coordinate.key(), 0) + 1
		var system = System.new(
			StringName("SYS-%s" % coordinate.key()),
			coordinate,
			Vector2(5.0, 6.0),
			&"red",
			&"procedural",
			coordinate,
			1
		)
		return Sector.new(coordinate, [system])


class FakeRepository:
	var calls := 0
	var anchors: Array = []


	func systems_in_bounds(_bounds: Rect2) -> Array:
		calls += 1
		return anchors


class FakeDensity:
	func density_at(position: Vector2) -> float:
		return clampf((position.x + position.y + 200.0) / 400.0, 0.0, 1.0)


func run() -> void:
	_test_lru_cache_and_exact_points()
	_test_catalog_and_density_queries()


func _test_lru_cache_and_exact_points() -> void:
	var source = FakeSectorSource.new()
	var repository = FakeRepository.new()
	var settings = Settings.duplicate(true)
	settings.minimap_cache_sector_limit = 2
	var service = QueryService.new(source, repository, settings, 1234, FakeDensity.new())
	var first := Coordinate.new(0, 0)
	var second := Coordinate.new(1, 0)
	var third := Coordinate.new(2, -1)
	service.exact_sector(first)
	service.exact_sector(second)
	service.exact_sector(first)
	assert_equal(source.calls["0:0"], 1, "cache hit avoids sector regeneration")
	service.exact_sector(third)
	assert_equal(service.cache_size(), 2, "cache remains at configured capacity")
	service.exact_sector(second)
	assert_equal(source.calls["1:0"], 2, "least recently used sector is evicted")

	var points: Array = service.exact_points(third)
	assert_equal(points.size(), 1, "exact sector exposes every system")
	assert_equal(points[0].position, Vector2(85.0, -34.0), "point uses global position")
	assert_equal(points[0].visual_type, &"red", "point preserves visual type")
	assert_equal(points[0].source, &"procedural", "point preserves source")


func _test_catalog_and_density_queries() -> void:
	var source = FakeSectorSource.new()
	var repository = FakeRepository.new()
	repository.anchors = [
		Anchor.new(&"SOL", "Sol", "Sol", Vector3(10.0, 20.0, 0.0))
	]
	var settings = Settings.duplicate(true)
	var service = QueryService.new(source, repository, settings, 5678, FakeDensity.new())
	var bounds := Rect2(-100.0, -100.0, 200.0, 200.0)
	var catalog: Array = service.catalog_points(bounds)
	assert_equal(repository.calls, 1, "catalog is queried once for the bounds")
	assert_equal(catalog[0].position, Vector2(10.0, 20.0), "catalog point uses anchor map position")
	assert_equal(catalog[0].source, &"catalog", "catalog point identifies its source")

	var cluster: Dictionary = service.sample_cell(bounds, 2, 3, &"cluster")
	var repeated: Dictionary = service.sample_cell(bounds, 2, 3, &"cluster")
	assert_equal(cluster, repeated, "cluster sampling is deterministic")
	assert_equal(cluster.rect, Rect2(0.0, 0.0, 100.0, 100.0), "cell index maps to grid rect")
	assert_true(cluster.estimated_count >= 0, "cluster exposes a nonnegative estimate")
	var density: Dictionary = service.sample_cell(bounds, 2, 3, &"density")
	assert_true(density.has("density"), "density cell exposes intensity")
	assert_true(not density.has("estimated_count"), "density cell omits cluster count")
