class_name LoadSystemComposition
extends RefCounted

const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")
const Factory = preload("res://scripts/domain/universe/procedural_system_factory.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")

var _repository: Repository
var _factory: Factory
var _universe_identity: Identity


func _init(
	source_repository: Repository,
	procedural_factory: Factory,
	identity: Identity
) -> void:
	_repository = source_repository
	_factory = procedural_factory
	_universe_identity = identity


func execute(system_definition: System) -> Composition:
	if system_definition.source == &"catalog":
		return _repository.system_composition(system_definition.id)
	if system_definition.source == &"procedural":
		return _factory.create(system_definition, _universe_identity)
	return null
