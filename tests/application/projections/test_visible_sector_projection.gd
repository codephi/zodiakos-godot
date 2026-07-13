extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const ProjectionScript = preload("res://scripts/application/projections/visible_sector_projection.gd")


func run() -> void:
	var projection = ProjectionScript.new()
	var center = Coordinate.new(4, -2)
	assert_equal(
		projection.load_radii(300.0, 16.0 / 9.0),
		Vector2i(8, 5),
		"maximum zoom covers 16:9 viewport plus one sector margin"
	)
	assert_equal(
		projection.load_radii(300.0, 9.0 / 16.0),
		Vector2i(4, 5),
		"portrait coverage follows the visible width"
	)
	assert_equal(
		projection.load_radii(300.0, 32.0 / 9.0),
		Vector2i(15, 5),
		"ultrawide coverage follows the visible width"
	)
	assert_equal(
		projection.load_radii(300.0, 1920.0),
		Vector2i(16, 5),
		"degenerate wide viewports clamp to a safe coverage"
	)
	assert_equal(
		projection.load_radii(300.0, 1.0 / 1920.0),
		Vector2i(2, 5),
		"degenerate tall viewports retain safe horizontal coverage"
	)
	var maximum_order = projection.load_order(center, {}, {}, Vector2i(8, 5))
	assert_equal(
		maximum_order.size(),
		187,
		"rectangular maximum coverage contains 17 by 11 sectors"
	)

	var order = projection.load_order(center, {}, {}, Vector2i(2, 2))
	assert_equal(order.size(), 25, "load radius contains 25 sectors")
	assert_equal(order[0].key(), center.key(), "center loads first")
	assert_equal(
		_keys(order).slice(1, 9),
		[
			"3:-3",
			"4:-3",
			"5:-3",
			"3:-2",
			"5:-2",
			"3:-1",
			"4:-1",
			"5:-1",
		],
		"equal-distance sectors use y then x order"
	)

	var active = {center.key(): true}
	var queued_coordinate = center.offset(-1, -1)
	var queued = {queued_coordinate.key(): true}
	var filtered_order = projection.load_order(center, active, queued, Vector2i(2, 2))
	assert_equal(filtered_order.size(), 23, "active and queued keys are excluded")
	assert_true(not _keys(filtered_order).has(center.key()), "active key is absent")
	assert_true(not _keys(filtered_order).has(queued_coordinate.key()), "queued key is absent")

	var distance_three = center.offset(3, 3)
	var far = [center.offset(4, 0), center.offset(0, -4), distance_three]
	var unload = projection.unload_coordinates(center, far, Vector2i(3, 3))
	assert_equal(unload.size(), 2, "only distance above three unloads")
	assert_true(not unload.has(distance_three), "distance three remains active")

	var rectangular_unload = projection.unload_coordinates(
		center,
		[center.offset(8, 0), center.offset(0, 6), center.offset(9, 0)],
		Vector2i(9, 6)
	)
	assert_equal(rectangular_unload.size(), 0, "coordinates inside rectangular radius remain")
	var beyond_rectangular = center.offset(0, 7)
	assert_equal(
		projection.unload_coordinates(center, [beyond_rectangular], Vector2i(9, 6)),
		[beyond_rectangular],
		"coordinate beyond either rectangular axis unloads"
	)


func _keys(coordinates: Array) -> Array:
	return coordinates.map(func(coordinate): return coordinate.key())
