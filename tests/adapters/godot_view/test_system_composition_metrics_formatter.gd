extends "res://tests/test_case.gd"

const Formatter = preload(
	"res://scripts/adapters/godot_view/system_composition_metrics_formatter.gd"
)
const Metrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)


func run() -> void:
	_test_formats_empty_and_populated_sources()
	_test_disabled_metrics_are_omitted()


func _test_formats_empty_and_populated_sources() -> void:
	var metrics = Metrics.new(true, 240)
	var formatter = Formatter.new()
	var empty: String = formatter.format(metrics.snapshot())
	assert_true(
		empty.contains("SS Procedural: avg -- | p95 -- | max -- | n=0"),
		"empty procedural metrics are explicit"
	)
	metrics.record_success(&"procedural", 1.25)
	metrics.record_success(&"procedural", 2.75)
	metrics.record_failure(&"procedural")
	metrics.record_success(&"catalog", 4.0)
	metrics.record_cache_hit()
	metrics.record_cache_miss()
	var text: String = formatter.format(metrics.snapshot())
	assert_true(
		text.contains("SS Procedural: avg 2.00 ms | p95 2.75 ms | max 2.75 ms | n=2"),
		"procedural durations use two decimals"
	)
	assert_true(text.contains("SS Catalog: avg 4.00 ms"), "catalog is separate")
	assert_true(text.contains("SS Cache: hits 1 | misses 1 | rate 50%"), "cache rate")


func _test_disabled_metrics_are_omitted() -> void:
	assert_equal(Formatter.new().format(Metrics.new(false, 240).snapshot()), "", "disabled")
