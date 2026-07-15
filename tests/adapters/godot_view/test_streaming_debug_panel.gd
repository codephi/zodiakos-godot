extends "res://tests/test_case.gd"

const PanelScript = preload(
	"res://scripts/adapters/godot_view/streaming_debug_panel.gd"
)
const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	var panel = PanelScript.new()
	Engine.get_main_loop().root.add_child(panel)
	var runtime_settings = Settings.duplicate(true)
	runtime_settings.stream_viewport_grid_size = 3
	panel.configure(runtime_settings)
	assert_true(not panel.visible, "debug panel starts hidden")
	assert_true(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "panel consumes mouse input")

	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	assert_true(panel.handle_toggle_input(f3), "pressed F3 is handled")
	assert_true(panel.visible, "F3 opens debug panel")
	var echoed_f3 := InputEventKey.new()
	echoed_f3.keycode = KEY_F3
	echoed_f3.pressed = true
	echoed_f3.echo = true
	assert_true(not panel.handle_toggle_input(echoed_f3), "echoed F3 is ignored")

	var proposals: Array = []
	panel.tuning_changed.connect(
		func(fixed: bool, zoom: float, grid: int, sectors: int, pending: int):
			proposals.append([fixed, zoom, grid, sectors, pending])
	)
	panel.fixed_check.set_pressed_no_signal(true)
	panel.fixed_zoom_spin.set_value_no_signal(1000.0)
	panel.grid_spin.set_value_no_signal(4.0)
	panel.sectors_spin.set_value_no_signal(0.0)
	panel.pending_spin.set_value_no_signal(7.0)
	panel.flush_pending_changes()
	assert_equal(panel.grid_spin.value, 5.0, "even grid normalizes upward")
	assert_equal(
		proposals,
		[[true, 1000.0, 5, 0, 7]],
		"panel emits every live tuning value"
	)

	panel.update_metrics({
		"camera_zoom": 30.0,
		"effective_preload_zoom": 1000.0,
		"visible_radii": Vector2i(1, 1),
		"load_radii": Vector2i(67, 38),
		"target_sectors": 10395,
		"active_sectors": 25,
		"pending_sectors": 256,
		"systems": 11,
		"stellar_lod_mode": &"stellar_glow",
		"stellar_points_2d": 0,
		"stellar_glow_instances": 11,
		"stellar_glow_pending": 2,
	})
	assert_true(panel.metrics_label.text.contains("Camera zoom: 30.0"), "panel shows camera zoom")
	assert_true(
		panel.metrics_label.text.contains("Preload zoom: 1000.0"),
		"panel shows effective preload zoom"
	)
	assert_true(panel.metrics_label.text.contains("Target: 10395"), "panel shows target")
	assert_true(panel.metrics_label.text.contains("Pending: 256"), "panel shows pending")
	assert_true(panel.metrics_label.text.contains("Stellar LOD: stellar_glow"), "panel shows stellar LOD")
	assert_true(panel.metrics_label.text.contains("Glow instances: 11"), "panel shows glow count")

	panel.show_validation_error("synthetic error")
	assert_equal(panel.error_label.text, "synthetic error", "panel shows validation error")
	var resets: Array[bool] = []
	panel.reset_requested.connect(func(): resets.append(true))
	panel.reset_button.pressed.emit()
	assert_equal(resets.size(), 1, "reset button emits reset request")
	panel.free()
