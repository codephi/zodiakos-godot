class_name StellarLightProfile
extends RefCounted

var system_id: StringName
var linear_color: Color
var combined_luminosity_solar: float
var display_scale: float
var pulse_phase: float
var visual_period_seconds: float
var pulse_amplitude: float
var halo_strength: float


func _init(
	profile_system_id: StringName,
	profile_color: Color,
	luminosity: float,
	scale: float,
	phase: float,
	period_seconds: float,
	amplitude: float,
	halo: float
) -> void:
	system_id = profile_system_id
	linear_color = profile_color
	combined_luminosity_solar = luminosity
	display_scale = scale
	pulse_phase = phase
	visual_period_seconds = period_seconds
	pulse_amplitude = amplitude
	halo_strength = halo


func as_dictionary() -> Dictionary:
	return {
		"system_id": system_id,
		"linear_color": linear_color,
		"combined_luminosity_solar": combined_luminosity_solar,
		"display_scale": display_scale,
		"pulse_phase": pulse_phase,
		"visual_period_seconds": visual_period_seconds,
		"pulse_amplitude": pulse_amplitude,
		"halo_strength": halo_strength,
	}
