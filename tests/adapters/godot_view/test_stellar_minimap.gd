extends "res://tests/test_case.gd"

const Minimap = preload("res://scripts/adapters/godot_view/stellar_minimap.gd")
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var settings = Settings.duplicate(true)
	var minimap = Minimap.new(settings)
	Engine.get_main_loop().root.add_child(minimap)
	_test_layout_and_metrics(minimap, settings)
	_test_snapshot_and_input_intents(minimap)
	minimap.free()


func _test_layout_and_metrics(minimap, settings) -> void:
	assert_equal(minimap.custom_minimum_size, settings.minimap_compact_size, "compact size")
	assert_equal(minimap.anchor_left, 1.0, "compact layout anchors right")
	assert_equal(minimap.anchor_top, 1.0, "compact layout anchors bottom")
	assert_true(minimap.mouse_filter == Control.MOUSE_FILTER_STOP, "panel consumes mouse")
	assert_true(minimap.canvas.mouse_filter == Control.MOUSE_FILTER_STOP, "canvas consumes mouse")

	var toggle := InputEventKey.new()
	toggle.keycode = KEY_M
	toggle.pressed = true
	assert_true(minimap.handle_toggle_input(toggle), "M toggles minimap")
	assert_true(minimap.expanded, "minimap expands")
	assert_true(is_equal_approx(minimap.anchor_left, 0.15), "expanded left anchor")
	assert_true(is_equal_approx(minimap.anchor_right, 0.85), "expanded right anchor")
	minimap.handle_toggle_input(toggle)
	assert_true(not minimap.expanded, "second M restores compact layout")


func _test_snapshot_and_input_intents(minimap) -> void:
	var snapshot := {
		"generation": 7,
		"lod": &"exact",
		"loading": true,
		"bounds": Rect2(-100.0, -50.0, 200.0, 100.0),
		"center": Vector2.ZERO,
		"view_height": 100.0,
		"systems": [{"position": Vector2.ZERO, "visual_type": &"yellow", "source": &"procedural"}],
		"cells": [{"rect": Rect2(-100.0, -50.0, 100.0, 50.0), "position": Vector2(-50.0, -25.0), "density": 0.5}],
		"catalog_systems": [{"position": Vector2(50.0, 25.0), "visual_type": &"yellow", "source": &"catalog"}],
		"visible_rect": Rect2(-10.0, -5.0, 20.0, 10.0),
		"preload_rect": Rect2(-40.0, -20.0, 80.0, 40.0),
		"error_count": 0,
		"sector_count": 8,
	}
	minimap.update_snapshot(snapshot)
	assert_true(minimap.status_label.text.contains("EXACT"), "status shows LOD")
	assert_true(minimap.status_label.text.contains("8 setores"), "status shows sector count")
	assert_equal(minimap.canvas.snapshot.systems.size(), 1, "canvas receives systems")
	assert_equal(minimap.canvas.snapshot.cells.size(), 1, "canvas receives density cells")
	assert_equal(minimap.canvas.snapshot.visible_rect, snapshot.visible_rect, "canvas receives visible overlay")
	assert_equal(minimap.canvas.snapshot.preload_rect, snapshot.preload_rect, "canvas receives preload overlay")

	var zooms: Array = []
	var pans: Array = []
	var navigations: Array = []
	var centers: Array[bool] = []
	minimap.zoom_requested.connect(func(steps, cursor, rect): zooms.append([steps, cursor, rect]))
	minimap.pan_requested.connect(func(delta, size): pans.append([delta, size]))
	minimap.navigation_requested.connect(func(target): navigations.append(target))
	minimap.center_requested.connect(func(): centers.append(true))

	minimap.canvas.size = Vector2(200.0, 100.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(150.0, 50.0)
	assert_true(minimap.handle_canvas_input(wheel), "wheel input is consumed")
	assert_equal(zooms[0][0], 1, "wheel up requests zoom in")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50.0, 50.0)
	minimap.handle_canvas_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(12.0, -4.0)
	assert_true(minimap.handle_canvas_input(motion), "drag input is consumed")
	assert_equal(pans[0], [Vector2(12.0, -4.0), Vector2(200.0, 100.0)], "drag intent includes panel size")

	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = Vector2(150.0, 75.0)
	minimap.handle_canvas_input(double_click)
	assert_true(navigations[0].is_equal_approx(Vector2(50.0, 25.0)), "double click maps to global coordinates")
	minimap.center_button.pressed.emit()
	assert_equal(centers.size(), 1, "center button emits intent")
