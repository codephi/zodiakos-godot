extends Node3D

const StarVisual = preload("res://scripts/visuals/star_visual.gd")
const ShipVisual = preload("res://scripts/visuals/ship_visual.gd")
const PlanetVisual = preload("res://scripts/visuals/planet_visual.gd")
const SegmentVisual = preload("res://scripts/visuals/connection_segment.gd")
const ZodiacVisual = preload("res://scripts/visuals/zodiac_area_visual.gd")
const Settings = preload("res://config/game_settings.tres")

const STAR_POSITIONS := [
	Vector3(-8.0, 0.35, -3.0),
	Vector3(-4.0, 0.35, 2.0),
	Vector3(0.0, 0.35, 6.0),
	Vector3(4.0, 0.35, 2.0),
	Vector3(8.0, 0.35, -3.0),
]
func _init() -> void:
	_add_environment()
	var stars := _add_container("Stars")
	var ships := _add_container("Ships")
	var planets := _add_container("Planets")
	var connections := _add_container("Connections")
	_add_zodiac_area()
	_add_stars(stars)
	_add_ships(ships)
	_add_planets(planets)
	_add_connections(connections)


func _add_container(node_name: String) -> Node3D:
	var container := Node3D.new()
	container.name = node_name
	add_child(container)
	return container


func _add_environment() -> void:
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Settings.demo_camera_position
	camera.rotation_degrees = Settings.demo_camera_rotation_degrees
	camera.fov = Settings.demo_camera_fov
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight"
	light.rotation_degrees = Settings.demo_light_rotation_degrees
	light.light_energy = Settings.demo_light_energy
	light.shadow_enabled = true
	add_child(light)

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Settings.demo_background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Settings.demo_ambient_light_color
	environment.ambient_light_energy = Settings.demo_ambient_light_energy
	world.environment = environment
	add_child(world)


func _add_zodiac_area() -> void:
	var area := ZodiacVisual.new(Settings)
	area.name = "ZodiacArea"
	add_child(area)
	area.configure(
		PackedVector3Array(
			[
				Vector3(-8.0, -0.2, -3.0),
				Vector3(0.0, -0.2, 6.0),
				Vector3(8.0, -0.2, -3.0),
			]
		),
		Settings.demo_owner_color
	)


func _add_stars(parent: Node3D) -> void:
	for index in Settings.demo_star_types.size():
		var star := StarVisual.new(Settings)
		star.name = "%sStar" % String(Settings.demo_star_types[index]).capitalize()
		star.position = STAR_POSITIONS[index]
		parent.add_child(star)
		star.configure(
			Settings.demo_star_types[index],
			Settings.demo_owner_color,
			index == 2
		)


func _add_ships(parent: Node3D) -> void:
	for index in Settings.demo_ship_classes.size():
		var ship := ShipVisual.new(Settings)
		ship.name = "%sShip" % String(Settings.demo_ship_classes[index]).capitalize()
		ship.position = Vector3(-3.0 + index * 3.0, 0.65, 0.5)
		parent.add_child(ship)
		ship.configure(Settings.demo_ship_classes[index], Settings.demo_owner_color)
		ship.set_direction(Vector3(1.0, 0.0, -1.0))


func _add_planets(parent: Node3D) -> void:
	for index in Settings.demo_planet_types.size():
		var planet := PlanetVisual.new(Settings)
		planet.name = "%sPlanet" % String(Settings.demo_planet_types[index]).capitalize()
		planet.position = Vector3(-4.5 + index * 3.0, 0.45, -6.0)
		parent.add_child(planet)
		planet.configure(Settings.demo_planet_types[index], 0.55 + index * 0.08)


func _add_connections(parent: Node3D) -> void:
	var zodiac_points := [STAR_POSITIONS[0], STAR_POSITIONS[2], STAR_POSITIONS[4]]
	for index in zodiac_points.size():
		var segment := SegmentVisual.new(Settings)
		segment.name = "TerritorySegment%d" % (index + 1)
		parent.add_child(segment)
		segment.configure_between(
			zodiac_points[index],
			zodiac_points[(index + 1) % zodiac_points.size()],
			Settings.demo_territory_line_thickness,
			Settings.demo_owner_color
		)

	var route := SegmentVisual.new(Settings)
	route.name = "TemporaryRoute"
	parent.add_child(route)
	route.configure_between(
		Vector3(-3.0, 0.5, 0.5),
		STAR_POSITIONS[3],
		Settings.demo_route_line_thickness,
		Settings.demo_route_color
	)
