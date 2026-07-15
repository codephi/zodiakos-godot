class_name StellarGlowBatchBuilder
extends RefCounted

var profile_service
var settings
var generation_id := 0
var coverage := Rect2()
var systems: Array = []
var current_index := 0
var transforms: Array[Transform3D] = []
var colors: Array[Color] = []
var custom_data: Array[Color] = []
var system_ids: Array[StringName] = []
var failures := 0
var started_usec := 0


func _init(service, configuration) -> void:
	profile_service = service
	settings = configuration


func begin(next_generation: int, next_coverage: Rect2, entries: Array) -> void:
	generation_id = next_generation
	coverage = next_coverage
	systems = entries.filter(
		func(entry): return coverage.has_point(entry.global_position)
	)
	systems.sort_custom(func(left, right): return String(left.id) < String(right.id))
	current_index = 0
	transforms.clear()
	colors.clear()
	custom_data.clear()
	system_ids.clear()
	failures = 0
	started_usec = Time.get_ticks_usec()


func process(limit := -1) -> int:
	var budget: int = settings.stellar_glow_profiles_per_frame if limit < 0 else limit
	var processed := 0
	while processed < budget and current_index < systems.size():
		var entry = systems[current_index]
		var profile = profile_service.execute(entry.definition)
		current_index += 1
		processed += 1
		if profile == null:
			failures += 1
			continue
		var basis := Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * profile.display_scale)
		transforms.append(Transform3D(basis, Vector3(entry.global_position.x, 0.0, entry.global_position.y)))
		colors.append(profile.linear_color)
		var period_unit := inverse_lerp(
			settings.stellar_glow_visual_period_range.x,
			settings.stellar_glow_visual_period_range.y,
			profile.visual_period_seconds
		)
		custom_data.append(Color(profile.pulse_phase, period_unit, profile.pulse_amplitude, profile.halo_strength))
		system_ids.append(entry.id)
	return processed


func cancel() -> void:
	systems.clear()
	current_index = 0


func is_complete() -> bool:
	return current_index >= systems.size()


func snapshot() -> Dictionary:
	return {
		"generation": generation_id,
		"coverage": coverage,
		"system_ids": system_ids.duplicate(),
		"transforms": transforms.duplicate(),
		"colors": colors.duplicate(),
		"custom_data": custom_data.duplicate(),
		"processed": current_index,
		"total": systems.size(),
		"failures": failures,
		"elapsed_ms": (Time.get_ticks_usec() - started_usec) / 1000.0 if started_usec > 0 else 0.0,
	}
