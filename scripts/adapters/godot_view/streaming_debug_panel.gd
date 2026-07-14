class_name StreamingDebugPanel
extends PanelContainer

signal tuning_changed(
	use_fixed_preload_zoom: bool,
	fixed_preload_zoom: float,
	viewport_grid_size: int,
	sectors_per_frame: int,
	max_pending_sectors: int
)
signal reset_requested

const DEBOUNCE_SECONDS := 0.15

var fixed_check: CheckBox
var fixed_zoom_spin: SpinBox
var grid_spin: SpinBox
var sectors_spin: SpinBox
var pending_spin: SpinBox
var reset_button: Button
var metrics_label: Label
var error_label: Label
var change_timer: Timer
var _suppress_changes := false


func _init() -> void:
	name = "StreamingDebugPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(340.0, 0.0)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -356.0
	offset_top = 16.0
	offset_right = -16.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(_label("Streaming ao vivo", 18))

	fixed_check = CheckBox.new()
	fixed_check.name = "FixedPreload"
	fixed_check.text = "Preload fixo"
	column.add_child(fixed_check)

	fixed_zoom_spin = _spin_box("FixedPreloadZoom", 0.0, 100000.0, 10.0)
	_add_field(column, "Zoom de preload", fixed_zoom_spin)
	grid_spin = _spin_box("ViewportGrid", 1.0, 99.0, 2.0)
	_add_field(column, "Grid de viewports", grid_spin)
	sectors_spin = _spin_box("SectorsPerFrame", 0.0, 4096.0, 1.0)
	_add_field(column, "Setores por frame", sectors_spin)
	pending_spin = _spin_box("MaxPendingSectors", 1.0, 1000000.0, 1.0)
	_add_field(column, "Máximo na fila", pending_spin)

	reset_button = Button.new()
	reset_button.name = "ResetDefaults"
	reset_button.text = "Restaurar padrões"
	column.add_child(reset_button)

	error_label = Label.new()
	error_label.name = "ValidationError"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.modulate = Color(1.0, 0.45, 0.45)
	error_label.visible = false
	column.add_child(error_label)

	var separator := HSeparator.new()
	column.add_child(separator)
	metrics_label = Label.new()
	metrics_label.name = "Metrics"
	metrics_label.text = "Aguardando métricas"
	column.add_child(metrics_label)

	change_timer = Timer.new()
	change_timer.name = "ChangeDebounce"
	change_timer.one_shot = true
	change_timer.wait_time = DEBOUNCE_SECONDS
	add_child(change_timer)

	fixed_check.toggled.connect(_on_fixed_toggled)
	fixed_zoom_spin.value_changed.connect(func(_value: float): _queue_numeric_change())
	grid_spin.value_changed.connect(func(_value: float): _queue_numeric_change())
	sectors_spin.value_changed.connect(func(_value: float): _queue_numeric_change())
	pending_spin.value_changed.connect(func(_value: float): _queue_numeric_change())
	reset_button.pressed.connect(func(): reset_requested.emit())
	change_timer.timeout.connect(flush_pending_changes)


func _label(text: String, font_size: int = 14) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	return result


func _spin_box(
	control_name: String,
	minimum: float,
	maximum: float,
	step_size: float
) -> SpinBox:
	var result := SpinBox.new()
	result.name = control_name
	result.min_value = minimum
	result.max_value = maximum
	result.step = step_size
	result.allow_greater = true
	result.update_on_text_changed = true
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


func _add_field(column: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var title_label := _label(title)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	row.add_child(control)
	column.add_child(row)


func configure(settings) -> void:
	_suppress_changes = true
	fixed_check.set_pressed_no_signal(settings.stream_use_fixed_preload_zoom)
	fixed_zoom_spin.set_value_no_signal(settings.stream_fixed_preload_zoom)
	grid_spin.set_value_no_signal(settings.stream_viewport_grid_size)
	sectors_spin.set_value_no_signal(settings.stream_sectors_per_frame)
	pending_spin.set_value_no_signal(settings.stream_max_pending_sectors)
	fixed_zoom_spin.editable = settings.stream_use_fixed_preload_zoom
	_suppress_changes = false


func handle_toggle_input(event: InputEvent) -> bool:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F3
	):
		visible = not visible
		return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if handle_toggle_input(event):
		get_viewport().set_input_as_handled()


func _on_fixed_toggled(enabled: bool) -> void:
	fixed_zoom_spin.editable = enabled
	if not _suppress_changes:
		flush_pending_changes()


func _queue_numeric_change() -> void:
	if not _suppress_changes:
		change_timer.start()


func flush_pending_changes() -> void:
	if _suppress_changes:
		return
	change_timer.stop()
	var grid := maxi(int(grid_spin.value), 1)
	if grid % 2 == 0:
		grid += 1
	grid_spin.set_value_no_signal(grid)
	tuning_changed.emit(
		fixed_check.button_pressed,
		fixed_zoom_spin.value,
		grid,
		int(sectors_spin.value),
		int(pending_spin.value)
	)


func update_metrics(snapshot: Dictionary) -> void:
	metrics_label.text = (
		"Camera zoom: %.1f\n"
		+ "Preload zoom: %.1f\n"
		+ "Visible radii: %s\n"
		+ "Load radii: %s\n"
		+ "Target: %d\n"
		+ "Active: %d\n"
		+ "Pending: %d\n"
		+ "Systems: %d"
	) % [
		float(snapshot.get("camera_zoom", 0.0)),
		float(snapshot.get("effective_preload_zoom", 0.0)),
		snapshot.get("visible_radii", Vector2i.ZERO),
		snapshot.get("load_radii", Vector2i.ZERO),
		int(snapshot.get("target_sectors", 0)),
		int(snapshot.get("active_sectors", 0)),
		int(snapshot.get("pending_sectors", 0)),
		int(snapshot.get("systems", 0)),
	]


func show_validation_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()
