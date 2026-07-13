extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const ProjectionScript = preload("res://scripts/application/projections/visible_sector_projection.gd")


func run() -> void:
	var projection = ProjectionScript.new()
	var center = Coordinate.new(4, -2)
	var order = projection.load_order(center, {}, {})
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
	var filtered_order = projection.load_order(center, active, queued)
	assert_equal(filtered_order.size(), 23, "active and queued keys are excluded")
	assert_true(not _keys(filtered_order).has(center.key()), "active key is absent")
	assert_true(not _keys(filtered_order).has(queued_coordinate.key()), "queued key is absent")

	var distance_three = center.offset(3, 3)
	var far = [center.offset(4, 0), center.offset(0, -4), distance_three]
	var unload = projection.unload_coordinates(center, far)
	assert_equal(unload.size(), 2, "only distance above three unloads")
	assert_true(not unload.has(distance_three), "distance three remains active")


func _keys(coordinates: Array) -> Array:
	return coordinates.map(func(coordinate): return coordinate.key())
