extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var coordinate = Coordinate.new(-7, 9)
	var first = Mixer.mix(Settings.universe_global_seed, coordinate, "cluster", 1, 2)
	var second = Mixer.mix(Settings.universe_global_seed, coordinate, "cluster", 1, 2)
	assert_equal(first, second, "derived seed is stable")
	assert_true(first >= 0, "derived seed is nonnegative")
	assert_true(
		first != Mixer.mix(Settings.universe_global_seed, coordinate, "isolated", 1, 2),
		"tag changes seed"
	)
	assert_true(
		first != Mixer.mix(Settings.universe_global_seed, coordinate.offset(1, 0), "cluster", 1, 2),
		"coordinate changes seed"
	)
	assert_true(
		first != Mixer.mix(Settings.universe_global_seed, coordinate, "cluster", 2, 1),
		"indices change seed"
	)

	var version: int = Settings.universe_generator_version
	var system = System.new(
		&"b", coordinate, Vector2(2, 3), &"yellow", &"cluster", coordinate, 10, version
	)
	var system_a = System.new(
		&"a", coordinate, Vector2(1, 1), &"red", &"isolated", coordinate, 9, version
	)
	var systems := [system, system_a]
	var sector = Sector.new(coordinate, systems, version)
	assert_equal(sector.systems[0].id, &"a", "sector sorts systems by id")
	systems.clear()
	assert_equal(sector.systems.size(), 2, "sector copies its source system array")
	var leaked_copy: Array = sector.systems
	leaked_copy.clear()
	assert_equal(sector.systems.size(), 2, "sector does not expose mutable system array")

	coordinate.x = 100
	coordinate.y = 200
	assert_equal(sector.coordinate.key(), "-7:9", "sector copies its source coordinate")
	assert_equal(system.sector.key(), "-7:9", "system copies its source sector")
	assert_equal(system.owner_sector.key(), "-7:9", "system copies its source owner sector")
	var leaked_sector = sector.coordinate
	leaked_sector.x = 300
	var leaked_system_sector = system.sector
	leaked_system_sector.y = 400
	var leaked_owner_sector = system.owner_sector
	leaked_owner_sector.x = 500
	assert_equal(sector.coordinate.key(), "-7:9", "sector does not expose mutable coordinate")
	assert_equal(system.sector.key(), "-7:9", "system does not expose mutable sector")
	assert_equal(system.owner_sector.key(), "-7:9", "system does not expose mutable owner sector")

	assert_equal(system.generator_version, version, "system generator version")
	assert_equal(sector.generator_version, version, "sector generator version")
	assert_equal(Settings.universe_sector_size, 40.0, "sector size")
	assert_equal(Settings.universe_generator_version, 1, "generator version")
	assert_equal(Settings.universe_min_clusters, 0, "minimum clusters")
	assert_equal(Settings.universe_max_clusters, 2, "maximum clusters")
	assert_equal(Settings.universe_min_cluster_stars, 8, "minimum cluster stars")
	assert_equal(Settings.universe_max_cluster_stars, 20, "maximum cluster stars")
	assert_equal(Settings.universe_min_cluster_radius, 8.0, "minimum cluster radius")
	assert_equal(Settings.universe_max_cluster_radius, 18.0, "maximum cluster radius")
	assert_equal(Settings.universe_max_isolated_stars, 3, "maximum isolated stars")
	assert_equal(Settings.universe_minimum_star_distance, 1.5, "minimum star distance")
	assert_equal(Settings.universe_max_stars_per_sector, 64, "maximum stars per sector")
	assert_equal(
		Settings.universe_visual_types,
		[&"yellow", &"red", &"white", &"orange", &"blue"],
		"visual types"
	)
	var position = PositionType.new(coordinate, Vector2.ZERO, Settings.universe_sector_size)
	assert_equal(position.sector_size, Settings.universe_sector_size, "position uses configured sector size")
