extends "res://tests/test_case.gd"

const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const View = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const Controller = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const StarVisualType = preload("res://scripts/visuals/star_visual.gd")
const StellarSystemDefinitionType = preload(
	"res://scripts/domain/universe/stellar_system_definition.gd"
)
const UniverseSectorType = preload("res://scripts/domain/universe/universe_sector.gd")
const Settings = preload("res://config/game_settings.tres")


class FakeRepository extends ScientificCatalogRepository:
	func metadata() -> CatalogMetadata:
		return CatalogMetadata.new(1, 2, 1)


class CountingGenerator extends RefCounted:
	var calls_by_sector := {}
	var delegate = Generator.new(FakeRepository.new())


	func generate_sector(coordinate):
		var key: String = coordinate.key()
		calls_by_sector[key] = calls_by_sector.get(key, 0) + 1
		return delegate.generate_sector(coordinate)


class TrackingView extends RefCounted:
	var delegate = View.new()
	var rebase_calls := 0


	func materialize_sector(sector, origin) -> void:
		delegate.materialize_sector(sector, origin)


	func remove_sector(coordinate) -> void:
		delegate.remove_sector(coordinate)


	func rebase(origin) -> void:
		rebase_calls += 1
		delegate.rebase(origin)


	func active_keys() -> Dictionary:
		return delegate.active_keys()


	func active_coordinates() -> Array:
		return delegate.active_coordinates()


	func active_sector_count() -> int:
		return delegate.active_sector_count()


	func system_count() -> int:
		return delegate.system_count()


	func free_delegate() -> void:
		delegate.free()


func run() -> void:
	_test_bounded_streaming_and_deterministic_rematerialization()
	_test_rapid_center_change_discards_stale_pending_sectors()
	_test_sector_placement_preserves_integer_precision()
	_test_unload_does_not_mutate_sector()
	_test_star_resources_are_shared_and_neutral_ring_is_not_configured()
	_test_stats_emit_only_when_observable_state_changes()
	_test_active_sector_is_not_regenerated()
	_test_intra_sector_motion_preserves_stream_state()
	_test_view_update_reconciles_even_when_radii_are_unchanged()
	_test_zoom_coverage_reuses_active_sectors_and_unloads_with_hysteresis()
	_test_non_positive_viewport_width_is_ignored()
	_test_extreme_positive_viewport_is_safely_bounded()
	_test_invalid_visual_type_materializes_with_safe_fallback()
	_test_stream_uses_injected_settings()


func _test_bounded_streaming_and_deterministic_rematerialization() -> void:
	var view = View.new()
	var controller = Controller.new()
	var generator = Generator.new(FakeRepository.new())
	controller.configure(generator, view, PositionType.new(Coordinate.new(), Vector2.ZERO))
	controller.process_pending()
	assert_equal(view.active_sector_count(), 2, "default batch loads at most two sectors")
	controller.process_pending(100)
	assert_equal(view.active_sector_count(), 25, "load radius creates 25 sectors")
	assert_true(view.system_count() > 0, "systems are materialized")
	var original_signature = view.sector_signature(Coordinate.new())
	controller.update_center(PositionType.new(Coordinate.new(10, 0), Vector2.ZERO))
	controller.process_pending(100)
	assert_true(view.active_sector_count() <= 49, "active sectors stay bounded")
	assert_true(not view.has_sector(Coordinate.new()), "distant origin unloads")
	controller.update_center(PositionType.new(Coordinate.new(), Vector2.ZERO))
	controller.process_pending(100)
	assert_equal(
		view.sector_signature(Coordinate.new()),
		original_signature,
		"return rematerializes same systems"
	)
	controller.free()
	view.free()


func _test_rapid_center_change_discards_stale_pending_sectors() -> void:
	var view = View.new()
	var controller = Controller.new()
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_center(PositionType.new(Coordinate.new(100, 100), Vector2.ZERO))
	controller.process_pending(100)
	assert_equal(view.active_sector_count(), 25, "replacement center loads exactly one window")
	assert_true(not view.has_sector(Coordinate.new()), "stale origin queue is discarded")
	assert_true(view.has_sector(Coordinate.new(100, 100)), "latest center is materialized")
	controller.free()
	view.free()


func _test_sector_placement_preserves_integer_precision() -> void:
	var view = View.new()
	var large_coordinate := 9007199254740992
	var coordinate = Coordinate.new(large_coordinate + 1, large_coordinate - 1)
	view.materialize_sector(
		Generator.new(FakeRepository.new()).generate_sector(coordinate),
		Coordinate.new(large_coordinate, large_coordinate)
	)
	assert_equal(
		view.get_node("Sector_%d_%d" % [coordinate.x, coordinate.y]).position,
		Vector3(40.0, 0.0, -40.0),
		"sector offset uses integer difference before float conversion"
	)
	view.free()


func _test_unload_does_not_mutate_sector() -> void:
	var coordinate = Coordinate.new(3, -4)
	var sector = Generator.new(FakeRepository.new()).generate_sector(coordinate)
	var signature_before: Array = sector.systems.map(func(system): return String(system.id))
	var view = View.new()
	view.materialize_sector(sector, coordinate)
	view.remove_sector(coordinate)
	assert_equal(
		sector.systems.map(func(system): return String(system.id)),
		signature_before,
		"unload leaves UniverseSector contents unchanged"
	)
	view.free()


func _test_star_resources_are_shared_and_neutral_ring_is_not_configured() -> void:
	var first_visual = StarVisualType.new()
	var second_visual = StarVisualType.new()
	first_visual.configure(&"yellow")
	second_visual.configure(&"yellow")
	assert_true(
		first_visual.get_node("Body").mesh == second_visual.get_node("Body").mesh,
		"stars share mesh"
	)
	assert_true(
		first_visual.get_node("Body").material_override
		== second_visual.get_node("Body").material_override,
		"same star type shares material"
	)
	assert_true(not first_visual.get_node("OwnerRing").visible, "neutral star skips owner ring")
	assert_true(
		first_visual.get_node("OwnerRing/Body").mesh == null,
		"neutral star does not configure owner ring geometry"
	)
	first_visual.free()
	second_visual.free()


func _test_stats_emit_only_when_observable_state_changes() -> void:
	var view = View.new()
	var controller = Controller.new()
	var emissions := [0]
	controller.stats_changed.connect(func(_sectors, _systems, _center): emissions[0] += 1)
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	assert_equal(emissions[0], 1, "configuration emits initial stream stats")
	controller.process_pending(0)
	controller.process_pending(0)
	assert_equal(emissions[0], 1, "idle processing does not repeat unchanged stats")
	controller.process_pending(1)
	assert_equal(emissions[0], 2, "materialization emits changed stats")
	controller.process_pending(0)
	assert_equal(emissions[0], 2, "idle processing remains silent after a load")
	controller.free()
	view.free()


func _test_active_sector_is_not_regenerated() -> void:
	var generator = CountingGenerator.new()
	var view = View.new()
	var controller = Controller.new()
	var origin = PositionType.new(Coordinate.new(), Vector2.ZERO)
	controller.configure(generator, view, origin)
	controller.process_pending(100)
	var calls_after_load: Dictionary = generator.calls_by_sector.duplicate()
	controller.update_center(origin)
	controller.process_pending(100)
	assert_equal(
		generator.calls_by_sector,
		calls_after_load,
		"an active sector is not regenerated when the center remains unchanged"
	)
	controller.free()
	view.free()


func _test_intra_sector_motion_preserves_stream_state() -> void:
	var generator = CountingGenerator.new()
	var view = TrackingView.new()
	var controller = Controller.new()
	var origin = PositionType.new(Coordinate.new(), Vector2.ZERO)
	controller.configure(generator, view, origin)
	controller.process_pending(1)
	var first_pending = controller.pending[0]
	var queued_before: Dictionary = controller.queued.duplicate()
	var active_before: Dictionary = view.active_keys()
	var calls_before: Dictionary = generator.calls_by_sector.duplicate()
	var rebase_calls_before: int = view.rebase_calls

	controller.update_center(PositionType.new(Coordinate.new(), Vector2(12.0, 7.0)))

	assert_equal(view.rebase_calls, rebase_calls_before, "intra-sector motion does not rebase")
	assert_true(
		is_same(controller.pending[0], first_pending),
		"intra-sector motion preserves the pending queue"
	)
	assert_equal(controller.queued, queued_before, "intra-sector motion preserves queued keys")
	assert_equal(view.active_keys(), active_before, "intra-sector motion preserves active sectors")
	assert_equal(
		generator.calls_by_sector,
		calls_before,
		"intra-sector motion does not invoke the generator"
	)
	controller.free()
	view.free_delegate()


func _test_view_update_reconciles_even_when_radii_are_unchanged() -> void:
	var view = TrackingView.new()
	var controller = Controller.new()
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	var rebase_calls_before: int = view.rebase_calls
	controller.update_view(50.0, Vector2(1920.0, 1080.0))
	assert_equal(
		view.rebase_calls,
		rebase_calls_before + 1,
		"view updates reconcile even when their rounded radii are unchanged"
	)
	controller.free()
	view.free_delegate()


func _test_zoom_coverage_reuses_active_sectors_and_unloads_with_hysteresis() -> void:
	var generator = CountingGenerator.new()
	var view = View.new()
	var controller = Controller.new(_unscaled_stream_settings())
	var origin = PositionType.new(Coordinate.new(), Vector2.ZERO)
	controller.configure(generator, view, origin)
	controller.update_view(300.0, Vector2(1920.0, 1080.0))
	controller.process_pending(controller.pending.size())
	assert_equal(
		view.active_sector_count(),
		187,
		"maximum zoom fills rectangular visible coverage"
	)
	var calls_at_maximum: Dictionary = generator.calls_by_sector.duplicate()
	controller.update_view(300.0, Vector2(1920.0, 1080.0))
	controller.process_pending(controller.pending.size())
	assert_equal(
		generator.calls_by_sector,
		calls_at_maximum,
		"unchanged view does not regenerate active sectors"
	)
	controller.update_view(50.0, Vector2(1920.0, 1080.0))
	controller.process_pending(controller.pending.size())
	assert_true(
		view.active_sector_count() <= 63,
		"zooming in unloads sectors outside hysteresis"
	)
	controller.free()
	view.free()


func _test_non_positive_viewport_width_is_ignored() -> void:
	var generator = CountingGenerator.new()
	var view = View.new()
	var controller = Controller.new(_unscaled_stream_settings())
	controller.configure(
		generator,
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_view(300.0, Vector2(1920.0, 1080.0))
	controller.process_pending(controller.pending.size())
	var radii_before: Vector2i = controller.load_radii
	var active_before: int = view.active_sector_count()
	var calls_before: Dictionary = generator.calls_by_sector.duplicate()

	controller.update_view(300.0, Vector2(0.0, 1080.0))
	controller.process_pending(controller.pending.size())
	assert_equal(controller.load_radii, radii_before, "zero viewport width keeps load radii")
	assert_equal(view.active_sector_count(), active_before, "zero viewport width keeps sectors")
	assert_equal(generator.calls_by_sector, calls_before, "zero viewport width skips generation")

	controller.update_view(300.0, Vector2(-1920.0, 1080.0))
	controller.process_pending(controller.pending.size())
	assert_equal(
		controller.load_radii,
		radii_before,
		"negative viewport width keeps load radii"
	)
	assert_equal(
		view.active_sector_count(),
		active_before,
		"negative viewport width keeps sectors"
	)
	assert_equal(
		generator.calls_by_sector,
		calls_before,
		"negative viewport width skips generation"
	)
	controller.free()
	view.free()


func _test_extreme_positive_viewport_is_safely_bounded() -> void:
	var controller = Controller.new(_unscaled_stream_settings())
	var view = View.new()
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_view(300.0, Vector2(1920.0, 1.0))
	assert_equal(
		controller.load_radii,
		Vector2i(16, 5),
		"one-pixel viewport height cannot create an unbounded stream"
	)
	assert_equal(
		controller.pending.size(),
		363,
		"bounded extreme coverage queues at most 33 by 11 sectors"
	)
	controller.free()
	view.free()


func _test_invalid_visual_type_materializes_with_safe_fallback() -> void:
	var coordinate = Coordinate.new()
	var invalid_visual_system = StellarSystemDefinitionType.new(
		&"invalid_visual",
		coordinate,
		Vector2(4.0, 6.0),
		&"not_a_visual_type",
		&"isolated",
		coordinate,
		1
	)
	var yellow_system = StellarSystemDefinitionType.new(
		&"yellow_visual",
		coordinate,
		Vector2(8.0, 6.0),
		&"yellow",
		&"isolated",
		coordinate,
		2
	)
	var view = View.new()
	view.materialize_sector(
		UniverseSectorType.new(coordinate, [invalid_visual_system, yellow_system]),
		coordinate
	)
	var visual = view.get_node("Sector_0_0/invalid_visual")
	assert_equal(visual.get_meta("system_id"), &"invalid_visual", "visual stores system id")
	assert_true(visual.get_node("Body").mesh != null, "invalid visual type uses a safe mesh")
	assert_true(
		visual.get_node("Body").material_override != null,
		"invalid visual type uses a safe material"
	)
	assert_true(
		visual.get_node("Body").material_override
		== view.get_node("Sector_0_0/yellow_visual/Body").material_override,
		"invalid visual type reuses the canonical fallback material"
	)
	view.free()


func _unscaled_stream_settings():
	var custom = Settings.duplicate(true)
	custom.stream_render_scale = 1.0
	custom.stream_load_margin = 1
	return custom


func _test_stream_uses_injected_settings() -> void:
	var custom = Settings.duplicate(true)
	custom.stream_initial_load_radii = Vector2i(1, 1)
	custom.stream_unload_margin = 2
	custom.stream_sectors_per_frame = 1
	var view = View.new()
	var controller = Controller.new(custom)
	controller.configure(
		Generator.new(FakeRepository.new(), custom),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO, custom.universe_sector_size)
	)
	assert_equal(controller.pending.size(), 9, "initial coverage uses injected settings")
	controller.process_pending()
	assert_equal(view.active_sector_count(), 1, "default frame budget uses injected settings")
	assert_equal(controller.unload_radii, Vector2i(3, 3), "unload radius uses configured margin")
	controller.free()
	view.free()
