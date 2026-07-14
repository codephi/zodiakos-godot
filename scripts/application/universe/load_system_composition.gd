class_name LoadSystemComposition
extends RefCounted

const Composition = preload("res://scripts/domain/universe/stellar_system_composition.gd")
const Factory = preload("res://scripts/domain/universe/procedural_system_factory.gd")
const Identity = preload("res://scripts/domain/universe/universe_identity.gd")
const Metrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")
const System = preload("res://scripts/domain/universe/stellar_system_definition.gd")

var _repository: Repository
var _factory: Factory
var _universe_identity: Identity
var _metrics: Metrics


func _init(
	source_repository: Repository,
	procedural_factory: Factory,
	identity: Identity,
	metrics: Metrics = null
) -> void:
	_repository = source_repository
	_factory = procedural_factory
	_universe_identity = identity
	_metrics = metrics


func execute(system_definition: System) -> Composition:
	var source: StringName = system_definition.source
	if source != &"catalog" and source != &"procedural":
		return null
	var started_usec := Time.get_ticks_usec()
	var composition: Composition
	if source == &"catalog":
		composition = _repository.system_composition(system_definition.id)
	else:
		composition = _factory.create(system_definition, _universe_identity)
	if _metrics != null:
		var duration_ms := (Time.get_ticks_usec() - started_usec) / 1000.0
		if composition == null:
			_metrics.record_failure(source)
		else:
			_metrics.record_success(source, duration_ms)
	return composition
