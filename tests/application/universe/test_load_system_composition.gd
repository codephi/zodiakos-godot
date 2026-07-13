extends "res://tests/test_case.gd"

const Body = preload("res://scripts/domain/universe/system_body_definition.gd")
const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const LoadSystemComposition = preload(
	"res://scripts/application/universe/load_system_composition.gd"
)
const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Settings = preload("res://config/game_settings.tres")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")


class RepositorySpy extends ScientificCatalogRepository:
	var result: StellarSystemComposition
	var requested_ids: Array[StringName] = []


	func _init(composition: StellarSystemComposition) -> void:
		result = composition


	func system_composition(system_id: StringName) -> StellarSystemComposition:
		requested_ids.append(system_id)
		return result


class FactorySpy extends ProceduralSystemFactory:
	var result: StellarSystemComposition
	var requested_systems: Array[StellarSystemDefinition] = []
	var requested_identities: Array[UniverseIdentity] = []


	func _init(composition: StellarSystemComposition) -> void:
		result = composition


	func create(
		system: StellarSystemDefinition,
		universe_identity: UniverseIdentity
	) -> StellarSystemComposition:
		requested_systems.append(system)
		requested_identities.append(universe_identity)
		return result


func run() -> void:
	_test_catalog_routes_only_to_repository()
	_test_procedural_routes_only_to_factory()
	_test_missing_catalog_does_not_fall_back_to_procedural()
	_test_unknown_source_returns_null_without_calls()


func _test_catalog_routes_only_to_repository() -> void:
	var expected := _composition(&"catalog:test")
	var repository := RepositorySpy.new(expected)
	var factory := FactorySpy.new(_composition(&"proc:unused"))
	var identity := _identity()
	var loader = LoadSystemComposition.new(repository, factory, identity)
	var definition := _system(&"catalog:test", &"catalog")

	assert_true(loader.execute(definition) == expected, "catalog returns repository composition")
	assert_equal(repository.requested_ids, [&"catalog:test"], "catalog repository called once")
	assert_equal(factory.requested_systems.size(), 0, "catalog never invokes procedural factory")


func _test_procedural_routes_only_to_factory() -> void:
	var expected := _composition(&"proc:test")
	var repository := RepositorySpy.new(_composition(&"catalog:unused"))
	var factory := FactorySpy.new(expected)
	var identity := _identity()
	var loader = LoadSystemComposition.new(repository, factory, identity)
	var definition := _system(&"proc:test", &"procedural")

	assert_true(loader.execute(definition) == expected, "procedural returns factory composition")
	assert_equal(factory.requested_systems, [definition], "procedural factory called once")
	assert_equal(factory.requested_identities, [identity], "factory receives injected identity")
	assert_equal(repository.requested_ids.size(), 0, "procedural never invokes catalog repository")


func _test_missing_catalog_does_not_fall_back_to_procedural() -> void:
	var repository := RepositorySpy.new(null)
	var factory := FactorySpy.new(_composition(&"proc:fallback"))
	var loader = LoadSystemComposition.new(repository, factory, _identity())

	assert_equal(
		loader.execute(_system(&"catalog:missing", &"catalog")),
		null,
		"missing catalog composition remains missing"
	)
	assert_equal(repository.requested_ids, [&"catalog:missing"], "missing catalog queried once")
	assert_equal(factory.requested_systems.size(), 0, "missing catalog has no procedural fallback")


func _test_unknown_source_returns_null_without_calls() -> void:
	var repository := RepositorySpy.new(_composition(&"catalog:unused"))
	var factory := FactorySpy.new(_composition(&"proc:unused"))
	var loader = LoadSystemComposition.new(repository, factory, _identity())

	assert_equal(
		loader.execute(_system(&"external:test", &"external")),
		null,
		"unknown source has no composition"
	)
	assert_equal(repository.requested_ids.size(), 0, "unknown source skips repository")
	assert_equal(factory.requested_systems.size(), 0, "unknown source skips factory")


func _composition(system_id: StringName) -> StellarSystemComposition:
	var primary = Body.new(
		StringName("%s:star" % system_id),
		&"star",
		"Primary",
		"",
		&"yellow",
		&"",
		{}
	)
	return Composition.new(system_id, [primary], [], [], [], [])


func _identity() -> UniverseIdentity:
	return Identity.new(
		101,
		Settings.universe_generator_version,
		Metadata.new(1, 2, 3),
		Settings
	)


func _system(system_id: StringName, source: StringName) -> StellarSystemDefinition:
	var coordinate := Coordinate.new(0, 0)
	return System.new(
		system_id,
		coordinate,
		Vector2(1.0, 2.0),
		&"yellow",
		source,
		coordinate,
		0
	)
