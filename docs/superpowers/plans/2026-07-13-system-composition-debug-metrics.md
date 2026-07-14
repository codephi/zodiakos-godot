# System Composition Debug Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure real catalog and procedural stellar-system composition work and display bounded statistics plus cache behavior in the existing debug HUD.

**Architecture:** A pure `SystemCompositionMetrics` collector owns bounded samples and returns defensive scalar snapshots. `LoadSystemComposition` records the actual synchronous execution boundary, while a presentation-only formatter converts snapshots into HUD text; the demo never generates systems solely to populate metrics.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, native Windows PowerShell, existing custom Godot test runner.

## Global Constraints

- Develop and test on native Windows; do not use WSL.
- Keep handwritten files at or below 1,000 lines.
- Use TDD: observe the focused test fail before writing production code.
- Keep metrics out of `UniverseIdentity` and all canonical generation inputs.
- Keep configuration in `config/game_settings.tres` with typed fields and validation in `scripts/config/game_settings.gd`.
- Retain only the latest 240 successful samples per source by default.
- Do not generate hidden benchmark SS; empty metrics render as `--`.
- Cache hits never enter procedural or catalog generation-time samples.
- Preserve the stable `CATALOG_INVALID:` error-only HUD behavior.
- Commit and push after every completed task.

---

### Task 1: Bounded system-composition metrics collector

**Files:**
- Create: `scripts/application/performance/system_composition_metrics.gd`
- Create: `tests/application/performance/test_system_composition_metrics.gd`
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/test_runner.gd`
- Modify: `docs/superpowers/plans/2026-07-13-adaptive-performance-foundations.md`

**Interfaces:**
- Consumes: `enabled: bool`, `sample_capacity: int`, source `StringName`, duration milliseconds.
- Produces: `record_success(source: StringName, duration_ms: float)`, `record_failure(source: StringName)`, `record_cache_hit()`, `record_cache_miss()`, `snapshot() -> Dictionary`.
- Snapshot keys: `enabled`, `procedural`, `catalog`, `cache`; source dictionaries contain `count`, `average_ms`, `p95_ms`, `maximum_ms`, `failures`; cache contains `hits`, `misses`, `hit_rate`.

- [ ] **Step 1: Add failing settings and collector tests**

Add these assertions to `tests/config/test_game_settings.gd`:

```gdscript
assert_true(Settings.performance_metrics_enabled, "performance metrics enabled")
assert_equal(Settings.performance_metrics_sample_capacity, 240, "metrics sample capacity")

_assert_validation_error(
	&"performance_metrics_sample_capacity",
	0,
	"performance_metrics_sample_capacity must be positive"
)
```

Create `tests/application/performance/test_system_composition_metrics.gd`:

```gdscript
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
```

Register the suite in `tests/test_runner.gd` immediately after the configuration
suite.

- [ ] **Step 2: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_system_composition_metrics.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: FAIL because the metrics script and settings fields do not exist.

- [ ] **Step 3: Add centralized metrics settings**

Add to `scripts/config/game_settings.gd` before the visual palette category:

```gdscript
@export_category("Performance Metrics")
@export var performance_metrics_enabled: bool
@export var performance_metrics_sample_capacity: int
```

Call `_validate_performance_metrics(errors)` from `validation_errors()` after
system composition validation, and add:

```gdscript
func _validate_performance_metrics(errors: PackedStringArray) -> void:
	_require_positive(
		errors,
		"performance_metrics_sample_capacity",
		performance_metrics_sample_capacity
	)
```

Add to `config/game_settings.tres` immediately after system composition fields:

```text
performance_metrics_enabled = true
performance_metrics_sample_capacity = 240
```

- [ ] **Step 4: Implement the collector**

Create `scripts/application/performance/system_composition_metrics.gd`:

```gdscript
class_name SystemCompositionMetrics
extends RefCounted

const PROCEDURAL := &"procedural"
const CATALOG := &"catalog"

var _enabled: bool
var _sample_capacity: int
var _samples := {PROCEDURAL: [], CATALOG: []}
var _failures := {PROCEDURAL: 0, CATALOG: 0}
var _cache_hits := 0
var _cache_misses := 0


func _init(enabled: bool, sample_capacity: int) -> void:
	assert(sample_capacity > 0, "Metrics sample capacity must be positive")
	_enabled = enabled
	_sample_capacity = sample_capacity


func record_success(source: StringName, duration_ms: float) -> void:
	if not _enabled or not _supports(source):
		return
	if duration_ms < 0.0 or is_nan(duration_ms) or is_inf(duration_ms):
		return
	var samples: Array = _samples[source]
	samples.append(duration_ms)
	if samples.size() > _sample_capacity:
		samples.pop_front()


func record_failure(source: StringName) -> void:
	if _enabled and _supports(source):
		_failures[source] += 1


func record_cache_hit() -> void:
	if _enabled:
		_cache_hits += 1


func record_cache_miss() -> void:
	if _enabled:
		_cache_misses += 1


func snapshot() -> Dictionary:
	var lookups := _cache_hits + _cache_misses
	return {
		"enabled": _enabled,
		"procedural": _source_snapshot(PROCEDURAL),
		"catalog": _source_snapshot(CATALOG),
		"cache": {
			"hits": _cache_hits,
			"misses": _cache_misses,
			"hit_rate": 0.0 if lookups == 0 else float(_cache_hits) / lookups,
		},
	}


func _source_snapshot(source: StringName) -> Dictionary:
	var samples: Array = _samples[source]
	if samples.is_empty():
		return {
			"count": 0,
			"average_ms": null,
			"p95_ms": null,
			"maximum_ms": null,
			"failures": _failures[source],
		}
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var total := 0.0
	for duration in samples:
		total += duration
	var p95_index := ceili(0.95 * sorted.size()) - 1
	return {
		"count": samples.size(),
		"average_ms": total / samples.size(),
		"p95_ms": sorted[p95_index],
		"maximum_ms": sorted.back(),
		"failures": _failures[source],
	}


func _supports(source: StringName) -> bool:
	return source == PROCEDURAL or source == CATALOG
```

In `docs/superpowers/plans/2026-07-13-adaptive-performance-foundations.md`,
remove the duplicate declaration of `performance_metrics_enabled` from Task 1
and state immediately after the global-field block:

```markdown
Reuse the existing `performance_metrics_enabled` and
`performance_metrics_sample_capacity` fields introduced by the system-composition
debug metrics plan. Do not redeclare them; retain their validation and Inspector
values while adding the remaining performance settings.
```

- [ ] **Step 5: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_system_composition_metrics.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1
```

Expected: all commands print `TESTS PASSED` and exit `0`.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/application/performance/system_composition_metrics.gd tests/application/performance/test_system_composition_metrics.gd scripts/config/game_settings.gd config/game_settings.tres tests/config/test_game_settings.gd tests/test_runner.gd docs/superpowers/plans/2026-07-13-adaptive-performance-foundations.md
git commit -m "feat: collect bounded system composition metrics"
git push
```

---

### Task 2: Measure real composition execution

**Files:**
- Modify: `scripts/application/universe/load_system_composition.gd`
- Modify: `tests/application/universe/test_load_system_composition.gd`

**Interfaces:**
- Consumes: optional `SystemCompositionMetrics` as the fourth constructor argument.
- Produces: unchanged `execute(system_definition: StellarSystemDefinition) -> StellarSystemComposition`; valid sources record one success or failure.
- Unknown sources record nothing; the loader remains usable with `metrics = null`.

- [ ] **Step 1: Write failing timing-boundary tests**

Add the preload:

```gdscript
const Metrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)
```

Register these tests in `run()` and add:

```gdscript
func _test_records_real_success_by_source() -> void:
	var metrics = Metrics.new(true, 240)
	var catalog_loader = LoadSystemComposition.new(
		RepositorySpy.new(_composition(&"catalog:timed")),
		FactorySpy.new(_composition(&"proc:unused")),
		_identity(),
		metrics
	)
	catalog_loader.execute(_system(&"catalog:timed", &"catalog"))
	var procedural_loader = LoadSystemComposition.new(
		RepositorySpy.new(_composition(&"catalog:unused")),
		FactorySpy.new(_composition(&"proc:timed")),
		_identity(),
		metrics
	)
	procedural_loader.execute(_system(&"proc:timed", &"procedural"))
	var data: Dictionary = metrics.snapshot()
	assert_equal(data.catalog.count, 1, "catalog execution measured once")
	assert_equal(data.procedural.count, 1, "procedural execution measured once")
	assert_true(data.catalog.average_ms >= 0.0, "catalog duration is nonnegative")
	assert_true(data.procedural.average_ms >= 0.0, "procedural duration is nonnegative")


func _test_records_failure_without_duration() -> void:
	var metrics = Metrics.new(true, 240)
	var loader = LoadSystemComposition.new(
		RepositorySpy.new(null),
		FactorySpy.new(_composition(&"proc:unused")),
		_identity(),
		metrics
	)
	loader.execute(_system(&"catalog:missing", &"catalog"))
	loader.execute(_system(&"external:unknown", &"external"))
	var data: Dictionary = metrics.snapshot()
	assert_equal(data.catalog.count, 0, "failure has no duration")
	assert_equal(data.catalog.failures, 1, "known source failure counted")
	assert_equal(data.procedural.failures, 0, "unknown source changes nothing")
```

- [ ] **Step 2: Run focused test and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_load_system_composition.gd'
```

Expected: FAIL because the loader constructor does not accept metrics.

- [ ] **Step 3: Instrument the existing use case**

Add the preload and field:

```gdscript
const Metrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)

var _metrics: Metrics
```

Change the constructor to:

```gdscript
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
```

Replace `execute` with:

```gdscript
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
```

- [ ] **Step 4: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_load_system_composition.gd'
./tools/run_godot_tests.ps1
```

Expected: both commands print `TESTS PASSED` and exit `0`.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/application/universe/load_system_composition.gd tests/application/universe/test_load_system_composition.gd
git commit -m "feat: measure system composition execution"
git push
```

---

### Task 3: Format and display composition metrics in the debug HUD

**Files:**
- Create: `scripts/adapters/godot_view/system_composition_metrics_formatter.gd`
- Create: `tests/adapters/godot_view/test_system_composition_metrics_formatter.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`
- Modify: `docs/superpowers/plans/2026-07-13-lazy-system-composition-and-auto-quality.md`

**Interfaces:**
- Formatter consumes: `format(snapshot: Dictionary) -> String`.
- Demo produces: public `composition_metrics: SystemCompositionMetrics`, `composition_loader: LoadSystemComposition`, and `refresh_debug_hud()` for main-thread consumers after completed composition work.
- Disabled snapshots format as an empty string; empty enabled sources format with `--`.

- [ ] **Step 1: Write failing formatter tests**

Create `tests/adapters/godot_view/test_system_composition_metrics_formatter.gd`:

```gdscript
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
```

Register it before the demo suites in `tests/test_runner.gd`.

- [ ] **Step 2: Add failing demo HUD assertions**

Extend `_test_hud_reports_map_stats_and_zoom()`:

```gdscript
assert_true(stats.text.contains("SS Procedural: avg --"), "HUD shows empty SS metrics")
assert_true(stats.text.contains("SS Catalog: avg --"), "HUD separates catalog metrics")
assert_true(stats.text.contains("SS Cache: hits 0"), "HUD shows cache metrics")
demo.composition_metrics.record_success(&"procedural", 2.5)
demo.refresh_debug_hud()
assert_true(stats.text.contains("SS Procedural: avg 2.50 ms"), "HUD refreshes metrics")
```

Add a test using the existing invalid repository fixture and assert its stats text
contains exactly one `CATALOG_INVALID:` and no `SS Procedural:` line.

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_system_composition_metrics_formatter.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

Expected: FAIL because the formatter and demo metrics integration do not exist.

- [ ] **Step 4: Implement the pure formatter**

Create `scripts/adapters/godot_view/system_composition_metrics_formatter.gd`:

```gdscript
class_name SystemCompositionMetricsFormatter
extends RefCounted


func format(snapshot: Dictionary) -> String:
	if not snapshot.enabled:
		return ""
	return "\n".join([
		_source_line("SS Procedural", snapshot.procedural),
		_source_line("SS Catalog", snapshot.catalog),
		_cache_line(snapshot.cache),
	])


func _source_line(label: String, source: Dictionary) -> String:
	if source.count == 0:
		return "%s: avg -- | p95 -- | max -- | n=0" % label
	return "%s: avg %.2f ms | p95 %.2f ms | max %.2f ms | n=%d" % [
		label,
		source.average_ms,
		source.p95_ms,
		source.maximum_ms,
		source.count,
	]


func _cache_line(cache: Dictionary) -> String:
	return "SS Cache: hits %d | misses %d | rate %.0f%%" % [
		cache.hits,
		cache.misses,
		cache.hit_rate * 100.0,
	]
```

- [ ] **Step 5: Integrate the collector and loader into the demo**

Add preloads to `scripts/demo/infinite_star_map_demo.gd`:

```gdscript
const CompositionMetrics = preload(
	"res://scripts/application/performance/system_composition_metrics.gd"
)
const CompositionMetricsFormatter = preload(
	"res://scripts/adapters/godot_view/system_composition_metrics_formatter.gd"
)
const LoadSystemComposition = preload(
	"res://scripts/application/universe/load_system_composition.gd"
)
const ProceduralSystemFactory = preload(
	"res://scripts/domain/universe/procedural_system_factory.gd"
)
```

Add state and initialize it before `_add_hud()`:

```gdscript
var composition_metrics
var composition_loader
var _composition_metrics_formatter

composition_metrics = CompositionMetrics.new(
	Settings.performance_metrics_enabled,
	Settings.performance_metrics_sample_capacity
)
_composition_metrics_formatter = CompositionMetricsFormatter.new()
```

After the universe generator identity is validated, create the production loader:

```gdscript
composition_loader = LoadSystemComposition.new(
	catalog_repository,
	ProceduralSystemFactory.new(),
	generator.identity,
	composition_metrics
)
```

Replace `_update_stats` and add the public main-thread refresh method:

```gdscript
func _update_stats(sectors: int, systems: int, center_key: String) -> void:
	var map_text := (
		"Seed: 0x%X\nSector: %s\nActive: %d\nSystems: %d\nZoom: %.1f"
		% [Settings.universe_global_seed, center_key, sectors, systems, map_camera.size]
	)
	var metrics_text: String = _composition_metrics_formatter.format(
		composition_metrics.snapshot()
	)
	stats_label.text = map_text if metrics_text.is_empty() else map_text + "\n" + metrics_text


func refresh_debug_hud() -> void:
	if stream.generator == null:
		return
	_update_stats(
		sector_view.active_sector_count(),
		sector_view.system_count(),
		map_camera.logical_position.sector.key()
	)
```

No timer or background benchmark calls `composition_loader.execute`. The future
selection controller invokes the loader/service for a real player request and
then calls `refresh_debug_hud()` on the main thread.

Update Task 6 of
`docs/superpowers/plans/2026-07-13-lazy-system-composition-and-auto-quality.md`
so the future `StreamingMetrics` composes this collector instead of duplicating
composition timing storage:

```markdown
`StreamingMetrics` receives the existing `SystemCompositionMetrics`. Its
defensive snapshot nests `composition_metrics.snapshot()` under `composition`.
The composition service records cache hits/misses on that shared collector; the
integration test repeats one request and asserts the cache hit increments without
adding a procedural or catalog timing sample.
```

- [ ] **Step 6: Run focused, full and smoke tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_system_composition_metrics_formatter.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

Expected: each test command prints `TESTS PASSED`; the smoke command exits `0`
without script errors.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/adapters/godot_view/system_composition_metrics_formatter.gd tests/adapters/godot_view/test_system_composition_metrics_formatter.gd scripts/demo/infinite_star_map_demo.gd tests/demo/test_infinite_star_map_demo.gd tests/test_runner.gd docs/superpowers/plans/2026-07-13-lazy-system-composition-and-auto-quality.md
git commit -m "feat: show system composition metrics in debug HUD"
git push
```
