class_name MapCameraController
extends Camera3D

signal logical_position_changed(position)
signal zoom_changed(new_size: float)

const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const DefaultSettings = preload("res://config/game_settings.tres")

var settings
var logical_position
var dragging := false
var drag_active := false
var drag_accumulator := Vector2.ZERO


func _init(configuration = DefaultSettings) -> void:
	settings = configuration
	logical_position = PositionType.new(
		Coordinate.new(),
		Vector2.ZERO,
		settings.universe_sector_size
	)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = settings.camera_initial_zoom
	rotation_degrees.x = -90.0
	position = Vector3(0.0, settings.camera_height, 0.0)
	current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				begin_drag()
			else:
				end_drag()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom_at(1, event.position, get_viewport().get_visible_rect().size)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom_at(-1, event.position, get_viewport().get_visible_rect().size)
	elif event is InputEventMouseMotion and dragging:
		var viewport_height := get_viewport().get_visible_rect().size.y
		accumulate_drag_pixels(event.relative, viewport_height)


func begin_drag() -> void:
	dragging = true
	drag_active = false
	drag_accumulator = Vector2.ZERO


func end_drag() -> void:
	dragging = false
	drag_active = false
	drag_accumulator = Vector2.ZERO


func accumulate_drag_pixels(delta: Vector2, viewport_height: float) -> void:
	drag_accumulator += delta
	if not drag_active and drag_accumulator.length() < settings.camera_drag_threshold_pixels:
		return
	drag_active = true
	apply_drag_pixels(drag_accumulator, viewport_height)
	drag_accumulator = Vector2.ZERO


func apply_drag_pixels(delta: Vector2, viewport_height: float) -> void:
	if viewport_height <= 0.0:
		return
	logical_position = logical_position.moved(-delta * (size / viewport_height))
	sync_visual_position()
	logical_position_changed.emit(logical_position)


func apply_zoom_steps(steps: int) -> void:
	apply_zoom_at(steps, Vector2.ZERO, Vector2.ZERO)


func apply_zoom_at(steps: int, cursor_position: Vector2, viewport_size: Vector2) -> void:
	var previous_size := size
	var next_size := previous_size
	if steps > 0:
		next_size *= pow(settings.camera_zoom_factor, steps)
	elif steps < 0:
		next_size /= pow(settings.camera_zoom_factor, -steps)
	next_size = clampf(next_size, settings.camera_min_zoom, settings.camera_max_zoom)
	if is_equal_approx(next_size, previous_size):
		return

	size = next_size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var cursor_from_center := cursor_position - viewport_size * 0.5
		var logical_delta := cursor_from_center * ((previous_size - next_size) / viewport_size.y)
		if not logical_delta.is_zero_approx():
			logical_position = logical_position.moved(logical_delta)
			sync_visual_position()
			logical_position_changed.emit(logical_position)
	zoom_changed.emit(size)


func sync_visual_position() -> void:
	position = Vector3(
		logical_position.local.x,
		settings.camera_height,
		logical_position.local.y
	)
