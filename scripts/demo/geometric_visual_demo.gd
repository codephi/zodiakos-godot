extends Node3D

const StarVisual = preload("res://scripts/visuals/star_visual.gd")
const ShipVisual = preload("res://scripts/visuals/ship_visual.gd")
const PlanetVisual = preload("res://scripts/visuals/planet_visual.gd")
const SegmentVisual = preload("res://scripts/visuals/connection_segment.gd")
const ZodiacVisual = preload("res://scripts/visuals/zodiac_area_visual.gd")

const OWNER_COLOR := Color("55a7ff")
const STAR_TYPES: Array[StringName] = [&"blue", &"white", &"yellow", &"orange", &"red"]
const STAR_POSITIONS := [
	Vector3(-8.0, 0.35, -3.0),
	Vector3(-4.0, 0.35, 2.0),
	Vector3(0.0, 0.35, 6.0),
	Vector3(4.0, 0.35, 2.0),
	Vector3(8.0, 0.35, -3.0),
]
const SHIP_CLASSES: Array[StringName] = [&"expedition", &"colony", &"war"]
const PLANET_TYPES: Array[StringName] = [&"rocky", &"gas", &"ice", &"volcanic"]


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
	camera.position = Vector3(0.0, 19.0, 20.0)
	camera.rotation_degrees = Vector3(-43.0, 0.0, 0.0)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight"
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6688aa")
	environment.ambient_light_energy = 1.2
	world.environment = environment
	add_child(world)


func _add_zodiac_area() -> void:
	var area := ZodiacVisual.new()
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
		OWNER_COLOR
	)


func _add_stars(parent: Node3D) -> void:
	for index in STAR_TYPES.size():
		var star := StarVisual.new()
		star.name = "%sStar" % String(STAR_TYPES[index]).capitalize()
		star.position = STAR_POSITIONS[index]
		parent.add_child(star)
		star.configure(STAR_TYPES[index], OWNER_COLOR, index == 2)


func _add_ships(parent: Node3D) -> void:
	for index in SHIP_CLASSES.size():
		var ship := ShipVisual.new()
		ship.name = "%sShip" % String(SHIP_CLASSES[index]).capitalize()
		ship.position = Vector3(-3.0 + index * 3.0, 0.65, 0.5)
		parent.add_child(ship)
		ship.configure(SHIP_CLASSES[index], OWNER_COLOR)
		ship.set_direction(Vector3(1.0, 0.0, -1.0))


func _add_planets(parent: Node3D) -> void:
	for index in PLANET_TYPES.size():
		var planet := PlanetVisual.new()
		planet.name = "%sPlanet" % String(PLANET_TYPES[index]).capitalize()
		planet.position = Vector3(-4.5 + index * 3.0, 0.45, -6.0)
		parent.add_child(planet)
		planet.configure(PLANET_TYPES[index], 0.55 + index * 0.08)


func _add_connections(parent: Node3D) -> void:
	var zodiac_points := [STAR_POSITIONS[0], STAR_POSITIONS[2], STAR_POSITIONS[4]]
	for index in zodiac_points.size():
		var segment := SegmentVisual.new()
		segment.name = "TerritorySegment%d" % (index + 1)
		parent.add_child(segment)
		segment.configure_between(
			zodiac_points[index],
			zodiac_points[(index + 1) % zodiac_points.size()],
			0.09,
			OWNER_COLOR
		)

	var route := SegmentVisual.new()
	route.name = "TemporaryRoute"
	parent.add_child(route)
	route.configure_between(
		Vector3(-3.0, 0.5, 0.5),
		STAR_POSITIONS[3],
		0.04,
		Color("ffdf80")
	)
