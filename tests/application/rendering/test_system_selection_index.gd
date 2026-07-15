extends "res://tests/test_case.gd"

const Index = preload("res://scripts/application/rendering/system_selection_index.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Settings = preload("res://config/game_settings.tres")

class Repo extends ScientificCatalogRepository:
	func metadata(): return Metadata.new(1, 1, 1)

func run() -> void:
	var index = Index.new(Settings.universe_sector_size)
	var sector = Generator.new(Repo.new()).generate_sector(Coordinate.new())
	index.add_sector(sector)
	if not sector.systems.is_empty():
		var system = sector.systems[0]
		assert_equal(index.pick(system.local_position, 0.01).id, system.id, "exact position selects system")
		index.remove_sector(Coordinate.new())
		assert_equal(index.pick(system.local_position, 10.0), null, "removed sector cannot be selected")
