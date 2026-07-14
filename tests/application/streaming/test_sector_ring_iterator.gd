extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Iterator = preload("res://scripts/application/streaming/sector_ring_iterator.gd")


func run() -> void:
	_test_exact_first_two_rings()
	_test_rectangular_clipping_and_total()
	_test_zero_radii_and_stable_exhaustion()
	_test_center_is_defensively_copied()


func _test_exact_first_two_rings() -> void:
	var iterator = Iterator.new(Coordinate.new(4, -2), Vector2i(2, 2))
	var keys := []
	for _index in 25:
		keys.append(iterator.next_coordinate().key())
	assert_equal(keys, [
		"4:-2",
		"3:-3", "4:-3", "5:-3", "3:-2", "5:-2", "3:-1", "4:-1", "5:-1",
		"2:-4", "3:-4", "4:-4", "5:-4", "6:-4",
		"2:-3", "6:-3", "2:-2", "6:-2", "2:-1", "6:-1",
		"2:0", "3:0", "4:0", "5:0", "6:0",
	], "center and first two rings retain distance/y/x order")
	var unique := {}
	for key in keys:
		unique[key] = true
	assert_equal(unique.size(), 25, "coordinates are unique")


func _test_rectangular_clipping_and_total() -> void:
	var wide := _drain(Iterator.new(Coordinate.new(), Vector2i(3, 1)))
	assert_equal(wide.size(), 21, "wide rectangle emits seven by three coordinates")
	assert_equal(wide[0], "0:0", "wide rectangle remains center-first")
	var tall := _drain(Iterator.new(Coordinate.new(), Vector2i(1, 3)))
	assert_equal(tall.size(), 21, "tall rectangle emits three by seven coordinates")


func _test_zero_radii_and_stable_exhaustion() -> void:
	var iterator = Iterator.new(Coordinate.new(2, 7), Vector2i.ZERO)
	assert_equal(iterator.next_coordinate().key(), "2:7", "zero radius emits center")
	assert_equal(iterator.next_coordinate(), null, "zero radius then exhausts")
	assert_true(iterator.is_exhausted(), "iterator exposes exhaustion")
	assert_equal(iterator.next_coordinate(), null, "exhaustion remains stable")


func _test_center_is_defensively_copied() -> void:
	var center = Coordinate.new(5, 6)
	var iterator = Iterator.new(center, Vector2i.ZERO)
	center.x = 99
	assert_equal(iterator.next_coordinate().key(), "5:6", "center mutation cannot alter iterator")


func _drain(iterator) -> Array:
	var keys := []
	while true:
		var coordinate = iterator.next_coordinate()
		if coordinate == null:
			return keys
		keys.append(coordinate.key())
	return keys
