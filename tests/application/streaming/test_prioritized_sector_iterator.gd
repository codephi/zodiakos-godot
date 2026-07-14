extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Iterator = preload(
	"res://scripts/application/streaming/prioritized_sector_iterator.gd"
)


func run() -> void:
	_test_visible_rectangle_precedes_external_coverage()
	_test_equal_radii_have_no_duplicates_and_exhaust_stably()
	_test_center_is_defensively_copied()


func _test_visible_rectangle_precedes_external_coverage() -> void:
	var keys := _drain(Iterator.new(
		Coordinate.new(),
		Vector2i(1, 0),
		Vector2i(2, 1)
	))
	assert_equal(
		keys.slice(0, 3),
		["0:0", "-1:0", "1:0"],
		"complete visible rectangle is emitted first"
	)
	assert_equal(keys[3], "-1:-1", "external phase starts after visible coverage")
	assert_equal(keys.size(), 15, "expanded five by three coverage is complete")
	var unique := {}
	for key in keys:
		unique[key] = true
	assert_equal(unique.size(), 15, "phases never repeat coordinates")


func _test_equal_radii_have_no_duplicates_and_exhaust_stably() -> void:
	var iterator = Iterator.new(Coordinate.new(), Vector2i(1, 1), Vector2i(1, 1))
	var keys := _drain(iterator)
	assert_equal(keys.size(), 9, "equal radii emit only the visible rectangle")
	assert_equal(iterator.next_coordinate(), null, "exhaustion remains stable")
	assert_true(iterator.is_exhausted(), "iterator exposes final exhaustion")


func _test_center_is_defensively_copied() -> void:
	var center = Coordinate.new(5, 6)
	var iterator = Iterator.new(center, Vector2i.ZERO, Vector2i.ZERO)
	center.x = 99
	assert_equal(iterator.next_coordinate().key(), "5:6", "center mutation is isolated")


func _drain(iterator) -> Array:
	var keys := []
	while true:
		var coordinate = iterator.next_coordinate()
		if coordinate == null:
			return keys
		keys.append(coordinate.key())
	return keys
