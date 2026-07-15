extends "res://tests/test_case.gd"

const Policy = preload("res://scripts/application/rendering/stellar_lod_policy.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var policy = Policy.new(Settings)
	assert_equal(policy.next_mode(&"points_2d", 199.9), &"stellar_glow", "below entry enables glow")
	assert_equal(policy.next_mode(&"points_2d", 200.0), &"points_2d", "entry boundary preserves points")
	assert_equal(policy.next_mode(&"stellar_glow", 219.9), &"stellar_glow", "hysteresis preserves glow")
	assert_equal(policy.next_mode(&"stellar_glow", 220.0), &"points_2d", "exit boundary forces points")
	assert_equal(
		policy.coverage_rect(Rect2(100.0, 50.0, 400.0, 200.0)),
		Rect2(-100.0, -50.0, 800.0, 400.0),
		"fifty percent per side doubles coverage"
	)
