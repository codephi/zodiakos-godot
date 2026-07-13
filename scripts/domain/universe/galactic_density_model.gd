class_name GalacticDensityModel
extends RefCounted

const DISK_TAPER_START_RATIO := 0.8
const SOLAR_RADIUS_PC := 8150.0
const INNER_ARM_CUTOFF_PC := 500.0
const CLUMP_BASE := 0.72
const CLUMP_X_SCALE_PC := 700.0
const CLUMP_Y_SCALE_PC := 900.0
const CLUMP_LOCAL_SCALE_PC := 240.0

var _settings: Resource


func _init(configuration: Resource) -> void:
	_settings = configuration


func contains(position: Vector2) -> bool:
	return position.length() < _settings.galaxy_halo_radius_pc


func density_at(position: Vector2) -> float:
	var radius := position.length()
	if radius >= _settings.galaxy_halo_radius_pc:
		return 0.0

	var disk := _disk_density(radius)
	var bulge := exp(-radius / _settings.galaxy_bulge_scale_radius_pc)
	var bar := _bar_density(position)
	var arms := _spiral_strength(position, radius)
	var clumps := _clump_strength(position)
	var halo := _halo_density(radius)
	var composite: float = (
		disk * (0.35 + 0.65 * arms) * clumps
		+ 0.9 * bulge
		+ 0.8 * bar
		+ halo
	) / 2.7
	return clampf(composite, 0.0, 1.0)


func _disk_density(radius: float) -> float:
	var density := exp(-radius / _settings.galaxy_disk_scale_length_pc)
	var taper_start: float = _settings.galaxy_disk_radius_pc * DISK_TAPER_START_RATIO
	density *= 1.0 - smoothstep(taper_start, _settings.galaxy_disk_radius_pc, radius)
	return density


func _bar_density(position: Vector2) -> float:
	var rotated := position.rotated(-deg_to_rad(_settings.galaxy_bar_angle_deg))
	var scaled := Vector2(
		rotated.x / _settings.galaxy_bar_half_length_pc,
		rotated.y / (_settings.galaxy_bar_half_length_pc * _settings.galaxy_bar_axis_ratio)
	)
	var bar_radius := scaled.length()
	return exp(-bar_radius * bar_radius)


func _spiral_strength(position: Vector2, radius: float) -> float:
	if radius < INNER_ARM_CUTOFF_PC:
		return 0.0

	var theta := position.angle()
	var pitch := deg_to_rad(_settings.galaxy_spiral_pitch_deg)
	var phase := log(radius / SOLAR_RADIUS_PC) / tan(pitch)
	var strongest := 0.0
	for arm in _settings.galaxy_spiral_arm_count:
		var center := phase + TAU * float(arm) / float(_settings.galaxy_spiral_arm_count)
		var angular := absf(wrapf(theta - center, -PI, PI))
		var distance := angular * radius
		var width: float = _settings.galaxy_spiral_arm_width_pc
		strongest = maxf(strongest, exp(-0.5 * pow(distance / width, 2.0)))
	return strongest


func _clump_strength(position: Vector2) -> float:
	return (
		CLUMP_BASE
		+ 0.12 * sin(position.x / CLUMP_X_SCALE_PC) * sin(position.y / CLUMP_Y_SCALE_PC)
		+ 0.08 * sin((position.x + position.y) / CLUMP_LOCAL_SCALE_PC)
	)


func _halo_density(radius: float) -> float:
	var fade := 1.0 - smoothstep(
		_settings.galaxy_disk_radius_pc,
		_settings.galaxy_halo_radius_pc,
		radius
	)
	return _settings.galaxy_halo_weight * fade
