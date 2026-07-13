extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Star = preload("res://scripts/domain/universe/star_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const Scale = preload("res://scripts/domain/universe/universe_scale.gd")


func run() -> void:
	var coordinate = Coordinate.new(-7, 9)
	var first = Mixer.mix(Config.GLOBAL_SEED, coordinate, "cluster", 1, 2)
	var second = Mixer.mix(Config.GLOBAL_SEED, coordinate, "cluster", 1, 2)
	assert_equal(first, second, "derived seed is stable")
	assert_true(first >= 0, "derived seed is nonnegative")
	assert_true(
		first != Mixer.mix(Config.GLOBAL_SEED, coordinate, "isolated", 1, 2),
		"tag changes seed"
	)
	assert_true(
		first != Mixer.mix(Config.GLOBAL_SEED, coordinate.offset(1, 0), "cluster", 1, 2),
		"coordinate changes seed"
	)
	assert_true(
		first != Mixer.mix(Config.GLOBAL_SEED, coordinate, "cluster", 2, 1),
		"indices change seed"
	)

	var star = Star.new(&"b", coordinate, Vector2(2, 3), &"yellow", &"cluster", coordinate, 10)
	var star_a = Star.new(&"a", coordinate, Vector2(1, 1), &"red", &"isolated", coordinate, 9)
	var stars := [star, star_a]
	var sector = Sector.new(coordinate, stars)
	assert_equal(sector.stars[0].id, &"a", "sector sorts stars by id")
	stars.clear()
	assert_equal(sector.stars.size(), 2, "sector copies its source star array")
	var leaked_copy: Array = sector.stars
	leaked_copy.clear()
	assert_equal(sector.stars.size(), 2, "sector does not expose mutable star array")

	coordinate.x = 100
	coordinate.y = 200
	assert_equal(sector.coordinate.key(), "-7:9", "sector copies its source coordinate")
	assert_equal(star.sector.key(), "-7:9", "star copies its source sector")
	assert_equal(star.owner_sector.key(), "-7:9", "star copies its source owner sector")
	var leaked_sector = sector.coordinate
	leaked_sector.x = 300
	var leaked_star_sector = star.sector
	leaked_star_sector.y = 400
	var leaked_owner_sector = star.owner_sector
	leaked_owner_sector.x = 500
	assert_equal(sector.coordinate.key(), "-7:9", "sector does not expose mutable coordinate")
	assert_equal(star.sector.key(), "-7:9", "star does not expose mutable sector")
	assert_equal(star.owner_sector.key(), "-7:9", "star does not expose mutable owner sector")

	assert_equal(star.generator_version, Config.GENERATOR_VERSION, "star generator version")
	assert_equal(sector.generator_version, Config.GENERATOR_VERSION, "sector generator version")
	assert_equal(Config.SECTOR_SIZE, 40.0, "sector size")
	_assert_sector_size_has_one_literal_source()
	assert_equal(Config.GENERATOR_VERSION, 1, "generator version")
	assert_equal(Config.MIN_CLUSTERS, 0, "minimum clusters")
	assert_equal(Config.MAX_CLUSTERS, 2, "maximum clusters")
	assert_equal(Config.MIN_CLUSTER_STARS, 8, "minimum cluster stars")
	assert_equal(Config.MAX_CLUSTER_STARS, 20, "maximum cluster stars")
	assert_equal(Config.MIN_CLUSTER_RADIUS, 8.0, "minimum cluster radius")
	assert_equal(Config.MAX_CLUSTER_RADIUS, 18.0, "maximum cluster radius")
	assert_equal(Config.MAX_ISOLATED_STARS, 3, "maximum isolated stars")
	assert_equal(Config.MINIMUM_DISTANCE, 1.5, "minimum star distance")
	assert_equal(Config.MAX_STARS_PER_SECTOR, 64, "maximum stars per sector")
	assert_equal(
		Config.VISUAL_TYPES,
		[&"yellow", &"red", &"white", &"orange", &"blue"],
		"visual types"
	)


func _assert_sector_size_has_one_literal_source() -> void:
	assert_equal(Config.SECTOR_SIZE, Scale.SECTOR_SIZE, "generator uses shared universe scale")
	assert_equal(PositionType.SECTOR_SIZE, Config.SECTOR_SIZE, "public sector size APIs agree")
