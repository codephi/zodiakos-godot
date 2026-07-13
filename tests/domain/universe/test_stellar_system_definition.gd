extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")


func run() -> void:
	var coordinate = Coordinate.new(203, 0)
	var owner = Coordinate.new(204, 1)
	var definition = System.new(
		&"catalog:sol",
		coordinate,
		Vector2(30.0, 0.0),
		&"yellow",
		&"catalog",
		owner,
		0,
		2,
		20.8
	)

	assert_equal(definition.id, &"catalog:sol", "system id")
	assert_equal(definition.sector.key(), "203:0", "system sector")
	assert_equal(definition.local_position, Vector2(30.0, 0.0), "local position")
	assert_equal(definition.visual_type, &"yellow", "visual type")
	assert_equal(definition.source, &"catalog", "system source")
	assert_equal(definition.owner_sector.key(), "204:1", "owner sector")
	assert_equal(definition.priority, 0, "system priority")
	assert_equal(definition.generator_version, 2, "generator version")
	assert_equal(definition.galactocentric_z_pc, 20.8, "scientific z")

	coordinate.x = 999
	owner.y = 999
	assert_equal(definition.sector.key(), "203:0", "system copies input sector")
	assert_equal(definition.owner_sector.key(), "204:1", "system copies input owner")
	var leaked_sector = definition.sector
	var leaked_owner = definition.owner_sector
	leaked_sector.y = 777
	leaked_owner.x = 777
	assert_equal(definition.sector.key(), "203:0", "system protects sector storage")
	assert_equal(definition.owner_sector.key(), "204:1", "system protects owner storage")

	var earlier = System.new(
		&"catalog:alpha", Coordinate.new(203, 0), Vector2.ZERO,
		&"red", &"catalog", Coordinate.new(203, 0), 1, 2, 0.0
	)
	var systems := [definition, earlier]
	var sector = Sector.new(Coordinate.new(203, 0), systems, 2)
	assert_true(sector.systems.is_typed(), "sector systems use a typed array")
	assert_equal(sector.systems[0].id, &"catalog:alpha", "sector sorts systems by id")
	systems.clear()
	assert_equal(sector.systems.size(), 2, "sector copies its source system array")
	var leaked_systems: Array = sector.systems
	leaked_systems.clear()
	assert_equal(sector.systems.size(), 2, "sector protects system storage")
	assert_equal(sector.system_count(), 2, "sector reports system count")
