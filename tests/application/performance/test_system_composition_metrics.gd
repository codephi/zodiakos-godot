extends "res://tests/test_case.gd"

const Metrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)


func run() -> void:
	_test_sources_are_independent_and_statistics_are_correct()
	_test_window_keeps_latest_samples()
	_test_failures_and_cache_do_not_change_timings()
	_test_snapshot_is_defensive()
	_test_disabled_and_invalid_records_are_ignored()


func _test_sources_are_independent_and_statistics_are_correct() -> void:
	var metrics = Metrics.new(true, 240)
	for value in [1.0, 2.0, 3.0, 4.0, 100.0]:
		metrics.record_success(&"procedural", value)
	metrics.record_success(&"catalog", 8.0)
	var data: Dictionary = metrics.snapshot()
	assert_equal(data.procedural.count, 5, "procedural sample count")
	assert_equal(data.procedural.average_ms, 22.0, "procedural arithmetic mean")
	assert_equal(data.procedural.p95_ms, 100.0, "nearest-rank p95")
	assert_equal(data.procedural.maximum_ms, 100.0, "procedural maximum")
	assert_equal(data.catalog.average_ms, 8.0, "catalog average is independent")


func _test_window_keeps_latest_samples() -> void:
	var metrics = Metrics.new(true, 3)
	for value in [1.0, 2.0, 3.0, 10.0]:
		metrics.record_success(&"procedural", value)
	var source: Dictionary = metrics.snapshot().procedural
	assert_equal(source.count, 3, "window is bounded")
	assert_equal(source.average_ms, 5.0, "oldest sample is evicted")


func _test_failures_and_cache_do_not_change_timings() -> void:
	var metrics = Metrics.new(true, 240)
	metrics.record_success(&"catalog", 6.0)
	metrics.record_failure(&"catalog")
	metrics.record_cache_hit()
	metrics.record_cache_hit()
	metrics.record_cache_miss()
	var data: Dictionary = metrics.snapshot()
	assert_equal(data.catalog.count, 1, "failure is not a duration")
	assert_equal(data.catalog.failures, 1, "catalog failure counted")
	assert_equal(data.cache.hits, 2, "cache hits counted")
	assert_equal(data.cache.misses, 1, "cache misses counted")
	assert_true(absf(data.cache.hit_rate - 2.0 / 3.0) < 0.0001, "hit rate")


func _test_snapshot_is_defensive() -> void:
	var metrics = Metrics.new(true, 240)
	metrics.record_success(&"procedural", 5.0)
	var first: Dictionary = metrics.snapshot()
	first.procedural.count = 99
	assert_equal(metrics.snapshot().procedural.count, 1, "snapshot cannot mutate metrics")


func _test_disabled_and_invalid_records_are_ignored() -> void:
	var metrics = Metrics.new(false, 240)
	metrics.record_success(&"procedural", 1.0)
	metrics.record_failure(&"procedural")
	metrics.record_cache_hit()
	assert_equal(metrics.snapshot().procedural.count, 0, "disabled samples ignored")
	assert_equal(metrics.snapshot().cache.hits, 0, "disabled cache ignored")

	var enabled = Metrics.new(true, 240)
	enabled.record_success(&"unknown", 2.0)
	enabled.record_success(&"catalog", -1.0)
	enabled.record_success(&"catalog", NAN)
	enabled.record_failure(&"unknown")
	assert_equal(enabled.snapshot().catalog.count, 0, "invalid records ignored")
