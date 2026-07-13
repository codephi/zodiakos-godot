class_name MapCameraController
extends Camera3D

signal logical_position_changed(position)
signal zoom_changed(new_size: float)

const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const MINIMUM_SIZE := 20.0
const MAXIMUM_SIZE := 300.0
const ZOOM_FACTOR := 0.88
const CAMERA_HEIGHT := 40.0
const DRAG_THRESHOLD_PIXELS := 4.0

var logical_position = PositionType.new(Coordinate.new(), Vector2.ZERO)
var dragging := false
var drag_active := false
var drag_accumulator := Vector2.ZERO


func _init() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 50.0
	rotation_degrees.x = -90.0
	position = Vector3(0.0, CAMERA_HEIGHT, 0.0)
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
	if not drag_active and drag_accumulator.length() < DRAG_THRESHOLD_PIXELS:
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
		next_size *= pow(ZOOM_FACTOR, steps)
	elif steps < 0:
		next_size /= pow(ZOOM_FACTOR, -steps)
	next_size = clampf(next_size, MINIMUM_SIZE, MAXIMUM_SIZE)
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
	position = Vector3(logical_position.local.x, CAMERA_HEIGHT, logical_position.local.y)
