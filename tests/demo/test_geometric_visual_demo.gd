extends "res://tests/test_case.gd"

const DemoScene = preload("res://scenes/demo/geometric_visual_demo.tscn")


func run() -> void:
	var demo := DemoScene.instantiate()
	assert_true(demo.get_node_or_null("Stars") != null, "demo has stars")
	assert_true(demo.get_node_or_null("Ships") != null, "demo has ships")
	assert_true(demo.get_node_or_null("Planets") != null, "demo has planets")
	assert_true(demo.get_node_or_null("Connections") != null, "demo has connections")
	assert_true(demo.get_node_or_null("ZodiacArea") != null, "demo has zodiac area")
	assert_equal(demo.get_node("Stars").get_child_count(), 5, "demo shows five star types")
	assert_equal(demo.get_node("Ships").get_child_count(), 3, "demo shows three ship classes")
	assert_equal(demo.get_node("Planets").get_child_count(), 4, "demo shows four planet types")
	for planet in demo.get_node("Planets").get_children():
		assert_true(planet.position.z <= 5.0, "planet remains inside preview depth")
	demo.free()
