extends "res://tests/test_case.gd"

const View = preload("res://scripts/adapters/godot_view/hybrid_star_field_view.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Settings = preload("res://config/game_settings.tres")

class Repo extends ScientificCatalogRepository:
	func metadata(): return Metadata.new(1, 1, 1)

func run() -> void:
	var view = View.new(Settings)
	var sector = Generator.new(Repo.new()).generate_sector(Coordinate.new())
	view.materialize_sector(sector, Coordinate.new())
	assert_equal(view.active_sector_count(), 1, "hybrid view retains sector data")
	assert_equal(view.system_count(), sector.system_count(), "hybrid view preserves system stats")
	assert_equal(view.get_child_count(), 1, "hybrid view creates one fixed canvas child")
	view.update_camera(Vector2.ZERO, 1000.0, Vector2(1000.0, 500.0))
	assert_equal(view.point_layer.systems.size(), sector.system_count(), "point layer receives systems")
	view.remove_sector(Coordinate.new())
	assert_equal(view.active_sector_count(), 0, "sector unload removes data")
	view.free()
