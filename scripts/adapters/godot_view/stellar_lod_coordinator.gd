class_name StellarLodCoordinator
extends RefCounted

const Policy = preload("res://scripts/application/rendering/stellar_lod_policy.gd")

var settings
var policy
var builder
var glow_layer
var mode: StringName = &"points_2d"
var generation_id := 0
var systems: Array = []
var visible_rect := Rect2()
var active_coverage := Rect2()
var suppressed_ids := {}


func _init(configuration, batch_builder, target_glow_layer) -> void:
	settings = configuration
	policy = Policy.new(settings)
	builder = batch_builder
	glow_layer = target_glow_layer


func notify_data_changed(next_systems: Array) -> void:
	systems = next_systems.duplicate()
	if mode != &"points_2d":
		_start_generation()


func update_camera(camera_global: Vector2, zoom: float, viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var view_size := Vector2(zoom * viewport_size.x / viewport_size.y, zoom)
	visible_rect = Rect2(camera_global - view_size * 0.5, view_size)
	var stable_mode := &"points_2d" if mode == &"points_2d" else &"stellar_glow"
	var desired: StringName = policy.next_mode(stable_mode, zoom)
	if desired == &"points_2d":
		if mode != &"points_2d":
			suppressed_ids.clear()
			glow_layer.clear()
			builder.cancel()
		mode = &"points_2d"
		return
	if mode == &"points_2d" or not active_coverage.encloses(visible_rect):
		_start_generation()


func process_pending(limit := -1) -> int:
	if mode != &"preparing_glow":
		return 0
	var processed: int = builder.process(limit)
	if builder.is_complete():
		var completed: Dictionary = builder.snapshot()
		glow_layer.publish(completed)
		suppressed_ids.clear()
		for id in completed.system_ids:
			suppressed_ids[id] = true
		active_coverage = completed.coverage
		mode = &"stellar_glow"
	return processed


func metrics() -> Dictionary:
	var state: Dictionary = builder.snapshot()
	return {
		"mode": mode,
		"generation": generation_id,
		"glow_instances": glow_layer.instance_count(),
		"pending": maxi(int(state.get("total", 0)) - int(state.get("processed", 0)), 0),
		"build_ms": float(state.get("elapsed_ms", 0.0)),
		"failures": int(state.get("failures", 0)),
	}


func _start_generation() -> void:
	generation_id += 1
	active_coverage = policy.coverage_rect(visible_rect)
	builder.begin(generation_id, active_coverage, systems)
	mode = &"preparing_glow"
