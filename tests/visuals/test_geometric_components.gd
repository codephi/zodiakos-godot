extends "res://tests/test_case.gd"

const ShipVisual = preload("res://scripts/visuals/ship_visual.gd")
const StarVisual = preload("res://scripts/visuals/star_visual.gd")
const PlanetVisual = preload("res://scripts/visuals/planet_visual.gd")
const ConnectionSegment = preload("res://scripts/visuals/connection_segment.gd")
const ZodiacAreaVisual = preload("res://scripts/visuals/zodiac_area_visual.gd")


func run() -> void:
	_test_ship_uses_one_geometric_base()
	_test_star_uses_sphere_and_owner_ring()
	_test_planet_uses_sphere()
	_test_connection_uses_midpoint_and_length()
	_test_zero_length_connection_is_hidden()
	_test_zodiac_requires_three_points()


func _test_ship_uses_one_geometric_base() -> void:
	var ship := ShipVisual.new()
	ship.configure(&"war", Color.BLUE)
	assert_true(ship.get_node("Body").mesh is PrismMesh, "ship uses PrismMesh")
	assert_equal(ship.scale, Vector3.ONE * 1.3, "war ship scale")
	assert_true(ship.get_node("OwnerRing").visible, "ship owner ring is visible")
	ship.free()


func _test_star_uses_sphere_and_owner_ring() -> void:
	var star := StarVisual.new()
	star.configure(&"red", Color.GREEN, true)
	assert_true(star.get_node("Body").mesh is SphereMesh, "star uses SphereMesh")
	assert_true(star.get_node("OwnerRing").visible, "owned star has ring")
	assert_equal(star.scale, Vector3.ONE * 0.8, "red star scale")
	star.free()


func _test_planet_uses_sphere() -> void:
	var planet := PlanetVisual.new()
	planet.configure(&"ice", 1.2)
	assert_true(planet.get_node("Body").mesh is SphereMesh, "planet uses SphereMesh")
	assert_equal(planet.scale, Vector3.ONE * 1.2, "planet size")
	planet.free()


func _test_connection_uses_midpoint_and_length() -> void:
	var segment := ConnectionSegment.new()
	segment.configure_between(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 0.1, Color.WHITE)
	assert_equal(segment.position, Vector3(5.0, 0.0, 0.0), "segment midpoint")
	assert_equal(segment.get_node("Body").mesh.size.x, 10.0, "segment length")
	segment.free()


func _test_zero_length_connection_is_hidden() -> void:
	var segment := ConnectionSegment.new()
	segment.configure_between(Vector3.ZERO, Vector3.ZERO, 0.1, Color.WHITE)
	assert_true(not segment.visible, "zero length segment is hidden")
	segment.free()


func _test_zodiac_requires_three_points() -> void:
	var area := ZodiacAreaVisual.new()
	area.configure(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]), Color.BLUE)
	assert_true(not area.visible, "invalid zodiac is hidden")
	area.configure(
		PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]),
		Color.BLUE
	)
	assert_true(area.visible, "valid zodiac is visible")
	assert_true(area.get_node("Body").mesh is ArrayMesh, "zodiac uses flat ArrayMesh")
	area.free()
