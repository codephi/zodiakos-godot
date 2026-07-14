extends "res://tests/test_case.gd"

const ProjectionScript = preload("res://scripts/application/minimap/minimap_projection.gd")
const LodPolicy = preload("res://scripts/application/minimap/minimap_lod_policy.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var projection = ProjectionScript.new(Vector2(100.0, -50.0), 400.0, 2.0)
	var drawing_rect := Rect2(10.0, 20.0, 800.0, 400.0)
	assert_equal(
		projection.bounds(),
		Rect2(-300.0, -250.0, 800.0, 400.0),
		"projection bounds use center height and aspect"
	)
	var center_pixel := projection.world_to_pixel(Vector2(100.0, -50.0), drawing_rect)
	assert_equal(center_pixel, Vector2(410.0, 220.0), "center maps to drawing center")
	assert_true(
		projection.pixel_to_world(center_pixel, drawing_rect).is_equal_approx(
			Vector2(100.0, -50.0)
		),
		"coordinate transforms are inverse"
	)
	var cursor := Vector2(610.0, 220.0)
	var anchored_world: Vector2 = projection.pixel_to_world(cursor, drawing_rect)
	var anchored = projection.zoom_at(
		1,
		cursor,
		drawing_rect,
		0.8,
		40.0,
		120000.0
	)
	assert_equal(anchored.view_height, 320.0, "positive step zooms in")
	assert_true(
		anchored.pixel_to_world(cursor, drawing_rect).is_equal_approx(anchored_world),
		"zoom remains anchored to cursor"
	)
	assert_equal(
		projection.zoom_at(100, cursor, drawing_rect, 0.8, 40.0, 120000.0).view_height,
		40.0,
		"zoom clamps to minimum height"
	)
	assert_equal(
		projection.zoom_at(-100, cursor, drawing_rect, 0.8, 40.0, 120000.0).view_height,
		120000.0,
		"zoom clamps to maximum height"
	)

	var policy = LodPolicy.new(Settings)
	assert_equal(policy.select(256), &"exact", "256 sectors use exact LOD")
	assert_equal(policy.select(257), &"cluster", "257 sectors use cluster LOD")
	assert_equal(policy.select(4096), &"cluster", "4096 sectors remain clustered")
	assert_equal(policy.select(4097), &"density", "4097 sectors use density LOD")
