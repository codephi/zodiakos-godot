class_name StellarMinimap
extends PanelContainer

signal pan_requested(delta_pixels: Vector2, panel_size: Vector2)
signal zoom_requested(steps: int, cursor_pixel: Vector2, drawing_rect: Rect2)
signal navigation_requested(target_global: Vector2)
signal center_requested

const Palette = preload("res://scripts/visuals/visual_palette.gd")


class MinimapCanvas extends Control:
	signal event_received(event: InputEvent)

	var snapshot: Dictionary = {}
	var settings


	func _init(configuration) -> void:
		settings = configuration
		name = "Canvas"
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(1.0, 1.0)


	func set_snapshot(next_snapshot: Dictionary) -> void:
		snapshot = next_snapshot.duplicate(true)
		queue_redraw()


	func _gui_input(event: InputEvent) -> void:
		event_received.emit(event)


	func _draw() -> void:
		if snapshot.is_empty():
			_draw_empty_state()
			return
		_draw_background()
		_draw_density_cells()
		_draw_clusters()
		_draw_systems()
		_draw_catalog_systems()
		_draw_world_rect(snapshot.get("preload_rect", Rect2()), Color(1.0, 0.55, 0.12, 0.9), 1.5)
		_draw_world_rect(snapshot.get("visible_rect", Rect2()), Color(0.2, 0.65, 1.0, 1.0), 2.0)
		_draw_center_cross()


	func _draw_empty_state() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.065, 0.96))
		_draw_center_cross()


	func _draw_background() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.065, 0.96))


	func _draw_density_cells() -> void:
		if snapshot.get("lod", &"exact") != &"density":
			return
		for cell in snapshot.get("cells", []):
			var density: float = clampf(float(cell.get("density", 0.0)), 0.0, 1.0)
			var cell_rect: Rect2 = cell.get("rect", Rect2())
			var pixel_rect := _map_world_rect(cell_rect)
			var color := Color(0.15, 0.35, 0.75, 0.08 + density * 0.62)
			draw_rect(pixel_rect, color, true)


	func _draw_clusters() -> void:
		if snapshot.get("lod", &"exact") != &"cluster":
			return
		for cell in snapshot.get("cells", []):
			var density: float = clampf(float(cell.get("density", 0.0)), 0.0, 1.0)
			if density <= 0.0:
				continue
			var estimated := maxi(int(cell.get("estimated_count", 0)), 1)
			var radius := clampf(2.0 + sqrt(float(estimated)), 2.0, 10.0)
			var position := _world_to_pixel(cell.get("position", Vector2.ZERO))
			draw_circle(position, radius, Color(0.35, 0.62, 1.0, 0.25 + density * 0.65))


	func _draw_systems() -> void:
		for system in snapshot.get("systems", []):
			var style: Dictionary = Palette.star_style(
				system.get("visual_type", &"yellow"),
				settings
			)
			var radius := clampf(float(style.get("scale", 1.0)) * 2.2, 1.5, 5.0)
			var position := _world_to_pixel(system.get("position", Vector2.ZERO))
			draw_circle(
				position,
				radius,
				style.get("color", Color.WHITE)
			)
			if system.get("source", &"procedural") == &"catalog":
				draw_arc(position, radius + 2.0, 0.0, TAU, 16, Color.WHITE, 1.5, true)


	func _draw_catalog_systems() -> void:
		for system in snapshot.get("catalog_systems", []):
			var position := _world_to_pixel(system.get("position", Vector2.ZERO))
			draw_arc(position, 4.5, 0.0, TAU, 16, Color.WHITE, 1.5, true)


	func _draw_world_rect(world_rect: Rect2, color: Color, width: float) -> void:
		if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
			return
		draw_rect(_map_world_rect(world_rect), color, false, width)


	func _draw_center_cross() -> void:
		var center := size * 0.5
		draw_line(center - Vector2(6.0, 0.0), center + Vector2(6.0, 0.0), Color(0.8, 0.9, 1.0, 0.8), 1.0)
		draw_line(center - Vector2(0.0, 6.0), center + Vector2(0.0, 6.0), Color(0.8, 0.9, 1.0, 0.8), 1.0)


	func _map_world_rect(world_rect: Rect2) -> Rect2:
		var start := _world_to_pixel(world_rect.position)
		var finish := _world_to_pixel(world_rect.end)
		return Rect2(start, finish - start)


	func _world_to_pixel(world: Vector2) -> Vector2:
		var bounds: Rect2 = snapshot.get("bounds", Rect2(Vector2(-0.5, -0.5), Vector2.ONE))
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			return size * 0.5
		return (world - bounds.position) / bounds.size * size


var settings
var canvas: MinimapCanvas
var status_label: Label
var center_button: Button
var expanded := false
var _snapshot: Dictionary = {}
var _dragging := false


func _init(configuration) -> void:
	settings = configuration
	name = "StellarMinimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = settings.minimap_compact_size
	_apply_layout()
	_build_content()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "MAPA ESTELAR"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.text = "AGUARDANDO"
	header.add_child(status_label)
	center_button = Button.new()
	center_button.name = "Center"
	center_button.text = "Centralizar"
	center_button.tooltip_text = "Voltar a acompanhar a câmera principal"
	header.add_child(center_button)

	canvas = MinimapCanvas.new(settings)
	column.add_child(canvas)
	canvas.event_received.connect(_on_canvas_event)
	center_button.pressed.connect(func(): center_requested.emit())


func update_snapshot(next_snapshot: Dictionary) -> void:
	_snapshot = next_snapshot.duplicate(true)
	var lod_name: String = str(_snapshot.get("lod", &"exact")).to_upper()
	var sector_count := int(_snapshot.get("sector_count", 0))
	var loading_suffix := " · carregando" if bool(_snapshot.get("loading", false)) else ""
	status_label.text = "%s · %d setores%s" % [lod_name, sector_count, loading_suffix]
	canvas.set_snapshot(_snapshot)


func handle_toggle_input(event: InputEvent) -> bool:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_M
	):
		expanded = not expanded
		_apply_layout()
		return true
	return false


func handle_canvas_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_requested.emit(1, event.position, Rect2(Vector2.ZERO, canvas.size))
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_requested.emit(-1, event.position, Rect2(Vector2.ZERO, canvas.size))
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				navigation_requested.emit(_pixel_to_world(event.position))
				_dragging = false
				return true
			_dragging = event.pressed
			return true
	if event is InputEventMouseMotion and (
		_dragging or event.button_mask & MOUSE_BUTTON_MASK_LEFT
	):
		pan_requested.emit(event.relative, canvas.size)
		return true
	return false


func _on_canvas_event(event: InputEvent) -> void:
	if handle_canvas_input(event):
		canvas.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if handle_toggle_input(event):
		get_viewport().set_input_as_handled()


func _apply_layout() -> void:
	if expanded:
		anchor_left = (1.0 - settings.minimap_expanded_screen_ratio) * 0.5
		anchor_top = (1.0 - settings.minimap_expanded_screen_ratio) * 0.5
		anchor_right = 1.0 - anchor_left
		anchor_bottom = 1.0 - anchor_top
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
		return
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -settings.minimap_compact_size.x - 16.0
	offset_top = -settings.minimap_compact_size.y - 16.0
	offset_right = -16.0
	offset_bottom = -16.0


func _pixel_to_world(pixel: Vector2) -> Vector2:
	var bounds: Rect2 = _snapshot.get("bounds", Rect2())
	if canvas.size.x <= 0.0 or canvas.size.y <= 0.0:
		return bounds.get_center()
	return bounds.position + pixel / canvas.size * bounds.size
