# Lazy System Composition and Automatic Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate complete systems only when selected or required, cache them in memory, expose user quality profiles, adapt quality from workload and report performance metrics.

**Architecture:** A request service deduplicates async composition jobs and owns a bounded LRU cache. User preference, effective profile and automatic control are separate services. Thin Godot panels consume signals and never own canonical rules.

**Tech Stack:** Godot 4.7, GDScript, ConfigFile, WorkerThreadPool adapter from Plan 2, Compatibility renderer, native Windows PowerShell.

## Global Constraints

- Plans 1, 2 and 3 must be complete.
- Complete SS composition remains deterministic and independent from profile.
- Catalog IDs never fall back to procedural composition.
- Procedural cache is memory-only and discarded at shutdown.
- Player preference is the only data persisted by this plan.
- Automatic quality uses workload time excluding VSync/idle wait.
- UI and metrics depend on application services, not the reverse.
- Keep every handwritten file at or below 1,000 lines.
- Use TDD, commit and push after every task.

---

### Task 1: Deduplicated lazy system-composition service

**Files:**
- Create: `scripts/application/universe/system_composition_request.gd`
- Create: `scripts/application/universe/system_composition_job_result.gd`
- Create: `scripts/application/universe/system_composition_service.gd`
- Create: `tests/application/universe/test_system_composition_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `LoadSystemComposition`, `TaskExecutor`, `UniverseIdentity`, catalog metadata and cache capacity.
- Produces: `request(system_definition) -> int`, `cancel_interest(request_id)`, `collect_completed(limit)`, `set_capacity(capacity)`, `cache_size()`, `shutdown()`.
- Signals: `composition_ready(request_id, system_id, composition)`, `composition_failed(request_id, system_id, message)`.
- `shutdown()` stops/drains composition work but does not close the borrowed shared executor.

- [ ] **Step 1: Write failing dedup/cache tests with manual executor**

```gdscript
var service = SystemCompositionService.new(loader, manual, identity, metadata, 2)
var first := service.request(procedural_system)
var second := service.request(procedural_system)
assert_equal(manual.pending_count(), 1, "same SS shares one job")
manual.complete_next()
service.collect_completed(10)
assert_equal(ready_request_ids, [first, second], "all interested requests receive result")
var third := service.request(procedural_system)
assert_equal(manual.pending_count(), 0, "cached SS skips executor")
assert_true(ready_request_ids.has(third), "cache hit is delivered")
```

Add cases for catalog/procedural key namespaces, LRU eviction, capacity zero,
canceled interest, missing catalog failure without procedural call, partial/null
result exclusion and shutdown. A procedural failure must retry exactly once while
at least one request remains interested; the second failure emits
`composition_failed` to every interested request. Catalog failures are terminal
and never fall back to procedural generation.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_system_composition_service.gd'
```

Expected: FAIL because service is missing.

- [ ] **Step 3: Implement immutable request/result records**

Request stores positive request ID, cache key and system definition. Result stores
cache key, composition or error. Cache keys are:

```gdscript
func _cache_key(system) -> String:
    if system.source == &"catalog":
        return "catalog:%d:%s" % [_metadata.catalog_version, system.id]
    return "procedural:%d:%s" % [_identity.value, system.id]
```

- [ ] **Step 4: Implement deduplicated service**

Main-thread dictionaries:

- `_inflight_by_key: key -> executor token`;
- `_requests_by_key: key -> Array[request_id]`;
- `_request_to_key`;
- `_cache: LruCache`.

The service extends `RefCounted`. `request` queues cache hits into
`_ready_deliveries`; the next `collect_completed` emits them, so callers always
receive results after obtaining the request ID. Worker jobs call the existing
`LoadSystemComposition.execute` using immutable snapshot/factory dependencies.
Composition jobs use `high_priority = true` on the shared executor. If capacity is
full, the key remains in `_waiting_keys` and `collect_completed` retries it before
collecting lower-priority work. The service borrows the executor and drains only
its own tokens on shutdown.

Keep `_attempts_by_key` with a maximum of two total procedural attempts. Remove
attempt state after success, terminal failure, cancellation of the last interest
or shutdown. Never cache null/partial results. Catalog jobs have one total attempt
because the startup snapshot is the authoritative source.

- [ ] **Step 5: Run focused/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_system_composition_service.gd'
./tools/run_godot_tests.ps1
git add scripts/application/universe/system_composition_request.gd scripts/application/universe/system_composition_job_result.gd scripts/application/universe/system_composition_service.gd tests/application/universe/test_system_composition_service.gd tests/test_runner.gd
git commit -m "feat: load system compositions on demand"
git push
```

### Task 2: Persistent player performance preference

**Files:**
- Create: `scripts/application/performance/performance_preference_store.gd`
- Create: `scripts/application/performance/performance_profile_service.gd`
- Create: `tests/application/performance/test_performance_profile_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Store produces: `load_profile(default_id) -> StringName`, `save_profile(profile_id) -> bool`, `reset() -> bool`.
- Service produces: `requested_profile_id`, `effective_profile_id`, `effective_profile()`, `select(profile_id) -> bool`, `reset()`, `set_automatic_effective(profile_id)`.
- Signal: `profile_changed(requested_id, effective_id, PerformanceProfile)`.

- [ ] **Step 1: Write failing preference tests**

Use the fixed isolated path `user://zodiakos-test-performance-profile.cfg`, remove
it before and after the suite, and assert missing/invalid files use Inspector default, every accepted
ID round-trips, reset removes preference, fixed selection changes requested and
effective together, and auto selection keeps requested `auto` while effective
starts at `medium`.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_performance_profile_service.gd'
```

- [ ] **Step 3: Implement ConfigFile store**

Accepted values are exactly `auto`, `low`, `medium`, `high`, `ultra`. Load any
other type/value as default. Save to section `performance`, key `profile`.
`reset` removes the file with `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` and treats a missing file as success.

- [ ] **Step 4: Implement profile service**

The service receives `GameSettings` and store. It validates requested IDs through
`GameSettings.performance_profile`. `auto` resolves initially to `medium`.
`set_automatic_effective` works only while requested is `auto` and accepts only
fixed profile IDs.

- [ ] **Step 5: Run tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_performance_profile_service.gd'
./tools/run_godot_tests.ps1
git add scripts/application/performance/performance_preference_store.gd scripts/application/performance/performance_profile_service.gd tests/application/performance/test_performance_profile_service.gd tests/test_runner.gd
git commit -m "feat: persist player performance profile"
git push
```

### Task 3: Automatic quality controller

**Files:**
- Create: `scripts/application/performance/frame_workload_window.gd`
- Create: `scripts/application/performance/automatic_quality_controller.gd`
- Create: `tests/application/performance/test_automatic_quality_controller.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `sample(workload_ms: float, observed_fps: float, elapsed_seconds: float, eligible: bool) -> StringName` returning a requested next effective ID or empty.
- Consumes: settings defaults and current effective profile ID.
- Produces: mean and p95 workload for metrics.

- [ ] **Step 1: Write failing window/controller tests**

Use small duplicated timing defaults for fast deterministic tests. Assert:

- window mean and nearest-rank p95;
- ineligible samples reset persistence timers but retain current profile;
- observed FPS below 98% of target or persistent p95 above `1000 / target_fps` lowers one level;
- observed FPS at least 98% of target and workload below 85% for the upgrade duration raises one level even with VSync at the target;
- cooldown blocks immediate reversal;
- Low/Ultra remain absolute bounds;
- one decision changes one level only.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_automatic_quality_controller.gd'
```

- [ ] **Step 3: Implement bounded workload window**

Store `(workload_ms, elapsed_seconds)` samples until accumulated duration reaches
`performance_auto_sample_seconds`; evict oldest samples beyond the window. Sort a
copy for nearest-rank p95. Reject negative workload/delta.

- [ ] **Step 4: Implement state machine**

Profile order is `[low, medium, high, ultra]`. During cooldown return empty. FPS
below 98% of target or workload above budget accumulates downgrade time and clears
upgrade time. FPS at target with workload below 85% accumulates upgrade time and
clears downgrade time. Middle band clears both. On threshold, return adjacent ID,
reset timers and start cooldown.

- [ ] **Step 5: Run tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_automatic_quality_controller.gd'
./tools/run_godot_tests.ps1
git add scripts/application/performance/frame_workload_window.gd scripts/application/performance/automatic_quality_controller.gd tests/application/performance/test_automatic_quality_controller.gd tests/test_runner.gd
git commit -m "feat: adapt quality from frame workload"
git push
```

### Task 4: Minimal performance settings panel

**Files:**
- Create: `scripts/adapters/godot_view/performance_settings_panel.gd`
- Create: `tests/adapters/godot_view/test_performance_settings_panel.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `PerformanceProfileService`.
- Produces: OptionButton with Automático/Baixo/Médio/Alto/Ultra, Apply button, Restore Default button and effective-profile label.
- Signal: `closed`.

- [ ] **Step 1: Write failing panel tests**

Assert exact option IDs/order, initial selection, apply calls service once, reset
restores Inspector default, `Automático (Médio)` text updates after effective
change and fixed profile displays only its localized label.

- [ ] **Step 2: Run RED and implement programmatic panel**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_performance_settings_panel.gd'
```

Build a `PanelContainer` with `VBoxContainer`, `OptionButton`, two buttons and a
label. Store canonical IDs as item metadata; never branch on translated text.
Connect service signal and disconnect automatically on tree exit.

- [ ] **Step 3: Run tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_performance_settings_panel.gd'
./tools/run_godot_tests.ps1
git add scripts/adapters/godot_view/performance_settings_panel.gd tests/adapters/godot_view/test_performance_settings_panel.gd tests/test_runner.gd
git commit -m "feat: choose player performance profile"
git push
```

### Task 5: Selection controller and loading system panel

**Files:**
- Create: `scripts/adapters/godot_view/system_info_panel.gd`
- Create: `scripts/application/universe/system_selection_controller.gd`
- Create: `tests/application/universe/test_system_selection_controller.gd`
- Create: `tests/adapters/godot_view/test_system_info_panel.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Selection controller consumes `system_selected(definition)` and `SystemCompositionService`.
- Produces: `selection_loading(system_id)`, `selection_ready(definition, composition)`, `selection_failed(system_id, message)`.
- Panel exposes `show_loading`, `show_composition`, `show_error`, `clear`.

- [ ] **Step 1: Write failing stale-selection tests**

Select A then B, complete A first and assert panel remains loading B; complete B and
assert counts render. Selecting cached B must not show a second worker request.
Failure shows explicit message. Clearing selection cancels interest without
invalidating cache work.

- [ ] **Step 2: Run RED and implement selection token ownership**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_system_selection_controller.gd'
```

Controller stores current definition/request ID. Ready/failed handlers compare
request ID before emitting UI signals. Previous interest is canceled when a new
selection starts.

- [ ] **Step 3: Implement panel rendering**

Loading shows designation/ID and `Carregando sistema...`. Ready shows source and
counts of stars, planets, moons and minor bodies. Error remains visible until a
new selection. This phase does not add planet-detail navigation.

- [ ] **Step 4: Integrate demo services**

Construct `LoadSystemComposition` from runtime snapshot, procedural factory and
identity; wrap it in `SystemCompositionService` using the single shared executor
created in Plan 2. Connect LOD selection to
selection controller and controller signals to panel. Call
`composition_service.collect_completed` each frame. During shutdown, stop/drain
sector, aggregate and composition services before closing the shared executor once.

- [ ] **Step 5: Run focused/full/smoke tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_system_selection_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_system_info_panel.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
git add scripts/adapters/godot_view/system_info_panel.gd scripts/application/universe/system_selection_controller.gd tests/application/universe/test_system_selection_controller.gd tests/adapters/godot_view/test_system_info_panel.gd scripts/demo/infinite_star_map_demo.gd tests/demo/test_infinite_star_map_demo.gd tests/test_runner.gd
git commit -m "feat: inspect systems through lazy composition"
git push
```

### Task 6: Performance metrics and automatic integration

**Files:**
- Create: `scripts/application/performance/streaming_metrics.gd`
- Create: `tests/application/performance/test_streaming_metrics.gd`
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/adapters/godot_view/galaxy_lod_controller.gd`
- Modify: `scripts/application/universe/system_composition_service.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Metrics records profile/LOD, queue/jobs, generation timings, cache hits/misses/evictions, active real/aggregate points and main-thread application time.
- Produces defensive `snapshot() -> Dictionary`.

- [ ] **Step 1: Write failing metrics tests**

Assert counters, bounded timing windows, mean/p95, defensive snapshots and reset.
Use explicit methods such as `record_sector_cache_hit`,
`record_sector_generation(milliseconds)` and `set_stream_state(pending, active)`;
do not expose mutable metric dictionaries to producers.

- [ ] **Step 2: Run RED and implement metrics collector**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_streaming_metrics.gd'
```

Keep at most 240 timing samples per category. Compute percentiles only when
snapshot is requested, not on every record.

- [ ] **Step 3: Add production instrumentation**

Inject the collector into stream, LOD and composition services. Measure work with
`Time.get_ticks_usec`; do not use frame delta as CPU workload. Update the demo HUD
only when metrics are enabled in settings.

- [ ] **Step 4: Drive automatic profile changes**

At the end of each frame, feed measured CPU/main-thread workload and
`Engine.get_frames_per_second()` into `AutomaticQualityController`. Pass `eligible = false` while paused,
unfocused or loading. When a new ID is returned, call
`PerformanceProfileService.set_automatic_effective`; propagate the effective
profile to LOD, scheduler, caches and aggregate budgets.

Apply a profile as one main-thread transaction in this order:

1. `shared_executor.set_capacity(profile.max_concurrent_jobs)`;
2. `sector_stream.set_profile(profile)` to resize pending limits and sector LRU;
3. `composition_service.set_capacity(profile.composition_cache_capacity)`;
4. `detail_view.set_profile(profile)` and `lod_controller.set_profile(profile)`;
5. publish the effective profile ID to metrics/HUD.

Capacity reductions do not cancel running jobs; they prevent new admission until
the active count is below the new limit. Cache resizes report evictions to metrics.

- [ ] **Step 5: Run tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/performance/test_streaming_metrics.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
git add scripts/application/performance/streaming_metrics.gd tests/application/performance/test_streaming_metrics.gd scripts/adapters/godot_view/sector_stream_controller.gd scripts/adapters/godot_view/galaxy_lod_controller.gd scripts/application/universe/system_composition_service.gd scripts/demo/infinite_star_map_demo.gd tests/demo/test_infinite_star_map_demo.gd tests/test_runner.gd
git commit -m "feat: observe and adapt galaxy performance"
git push
```

### Task 7: Full performance and determinism gate

**Files:**
- Create: `docs/performance/adaptive-streaming-benchmark.md`

**Interfaces:**
- Verifies the complete spec; does not introduce new gameplay.

- [ ] **Step 1: Run all automated gates with catalog hash**

```powershell
$db='data/catalog/zodiakos_catalog.sqlite'
$before=(Get-FileHash $db -Algorithm SHA256).Hash
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
$after=(Get-FileHash $db -Algorithm SHA256).Hash
if($before -ne $after){ throw 'Scientific catalog changed' }
```

Expected: full PASS, `CATALOG VALID`, equal hashes.

- [ ] **Step 2: Run an 1,800-frame lifecycle smoke**

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 1800
if($LASTEXITCODE -ne 0){ throw "Smoke failed: $LASTEXITCODE" }
```

Expected: exit `0`, no orphan task, SQLite or SceneTree errors.

- [ ] **Step 3: Perform GUI benchmark scenarios**

Record Windows version, CPU, GPU, RAM, resolution and Godot version. Run:

1. maximum zoom and continuous pan for 30 measured seconds;
2. overview -> cluster -> detail transitions ten times;
3. pan across 100 detailed sectors;
4. open the same procedural SS ten times;
5. open Sol ten times;
6. run automatic mode long enough to observe one controlled level change.

Capture average FPS, p95 workload, max queue/jobs, cache hit ratios and instance
counts in `docs/performance/adaptive-streaming-benchmark.md`. The report must use
observed values, not estimates.

- [ ] **Step 4: Confirm user-visible behavior**

- Overview/cluster are not individually selectable.
- Detail selects Sol and procedural systems.
- Loading panel never freezes camera movement.
- Quality preference survives restart.
- Automatic label shows its effective level.
- Returning to cached region/system avoids regeneration.

- [ ] **Step 5: Commit and push benchmark or gate fixes**

If any gate fails, return to the responsible task, fix it with TDD and use that
task's explicit staging list before continuing. After every gate passes, commit
only the observed benchmark report:

```powershell
git add docs/performance/adaptive-streaming-benchmark.md
git commit -m "test: verify adaptive galaxy performance"
git push
```
