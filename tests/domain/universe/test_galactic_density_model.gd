extends "res://tests/test_case.gd"

const GalacticDensity = preload("res://scripts/domain/universe/galactic_density_model.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var model = GalacticDensity.new(Settings)
	var solar_position := Vector2(8150.0, 0.0)

	assert_true(
		model.density_at(Vector2.ZERO) > model.density_at(solar_position),
		"center is denser than the solar neighborhood"
	)
	assert_true(model.density_at(solar_position) > 0.0, "solar region is populated")
	assert_true(model.density_at(Vector2(55000.0, 0.0)) > 0.0, "sparse halo exists")
	assert_equal(
		model.density_at(Vector2(60000.0, 0.0)),
		0.0,
		"outer boundary is void"
	)
	assert_equal(
		model.density_at(Vector2(70000.0, 0.0)),
		0.0,
		"outside remains void"
	)
	assert_true(
		model.density_at(Vector2(4000.0, 0.0))
		!= model.density_at(Vector2(0.0, 4000.0)),
		"rotated bar is anisotropic"
	)

	assert_true(model.contains(Vector2(59999.0, 0.0)), "inner halo is contained")
	assert_true(not model.contains(Vector2(60000.0, 0.0)), "halo boundary is excluded")
	assert_true(not model.contains(Vector2(70000.0, 0.0)), "exterior is excluded")

	var inter_arm_position := Vector2.from_angle(PI / 4.0) * solar_position.length()
	assert_true(
		model.density_at(solar_position) > model.density_at(inter_arm_position),
		"solar-radius arm is denser than a comparable inter-arm point"
	)

	var edge_samples := [
		Vector2.ZERO,
		Vector2(500.0, 0.0),
		Vector2(-4000.0, 2700.0),
		Vector2(8150.0, 0.0),
		Vector2(12000.0, -9000.0),
		Vector2(-30000.0, 20000.0),
		Vector2(55000.0, 0.0),
		Vector2(59999.0, 0.0),
		Vector2(60000.0, 0.0),
		Vector2(70000.0, -70000.0),
	]
	for position in edge_samples:
		_assert_density_sample(model, position)

	var grid_axis := [-59000.0, -30000.0, 0.0, 30000.0, 59000.0]
	for x in grid_axis:
		for y in grid_axis:
			_assert_density_sample(model, Vector2(x, y))


func _assert_density_sample(model: RefCounted, position: Vector2) -> void:
	var first: float = model.density_at(position)
	var second: float = model.density_at(position)
	assert_true(is_finite(first), "sample density is finite at %s" % position)
	assert_true(first >= 0.0 and first <= 1.0, "sample density is normalized at %s" % position)
	assert_equal(first, second, "sample density is deterministic at %s" % position)
