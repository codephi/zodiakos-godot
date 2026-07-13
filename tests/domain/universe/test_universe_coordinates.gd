extends "res://tests/test_case.gd"

const SectorCoordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const UniversePosition = preload("res://scripts/domain/universe/universe_position.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var origin = UniversePosition.new(
		SectorCoordinate.new(0, 0),
		Vector2.ZERO,
		Settings.universe_sector_size
	)
	var negative = origin.moved(Vector2(-0.1, -0.1))
	assert_equal(negative.sector.key(), "-1:-1", "negative movement changes sector")
	assert_true(negative.local.is_equal_approx(Vector2(39.9, 39.9)), "negative local wraps")
	var edge = origin.moved(Vector2(40.0, 40.0))
	assert_equal(edge.sector.key(), "1:1", "positive edge changes sector")
	assert_equal(edge.local, Vector2.ZERO, "positive edge resets local")
	var huge = SectorCoordinate.new(1 << 40, -(1 << 40))
	assert_equal(huge.key(), "1099511627776:-1099511627776", "coordinate exceeds 32 bits")
	var nearby = UniversePosition.new(huge.offset(2, -1), Vector2(5.0, 7.0))
	assert_equal(nearby.relative_to(huge), Vector2(85.0, -33.0), "relative position stays small")
	assert_equal(huge.chebyshev_distance(huge.offset(-4, 2)), 4, "chebyshev distance")

	var small_sectors = UniversePosition.new(SectorCoordinate.new(), Vector2(12.0, 0.0), 10.0)
	assert_equal(small_sectors.sector.key(), "1:0", "custom sector size normalizes position")
	assert_equal(small_sectors.local, Vector2(2.0, 0.0), "custom sector size wraps local")
