# Bounded Async Sector Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unbounded synchronous sector queue with bounded center-first scheduling, an immutable scientific snapshot, CPU worker jobs and an LRU-backed streaming controller.

**Architecture:** A pure scheduler emits a bounded sequence of immutable requests. A reusable task executor runs sector generation away from the main thread using only in-memory data; the main thread owns caches, relevance checks and view mutation.

**Tech Stack:** Godot 4.7, GDScript, WorkerThreadPool, SQLite read-only startup adapter, native Windows PowerShell.

## Global Constraints

- Plan 1 (`2026-07-13-adaptive-performance-foundations.md`) must be complete.
- Develop on native Windows with Godot 4.7 Compatibility renderer.
- Never access SceneTree or a shared SQLite connection from a worker.
- Every WorkerThreadPool task must be waited before its resources are released.
- Queue, jobs, cache and main-thread work remain bounded by the effective profile.
- Same identity and coordinate must produce the same sector regardless of job order.
- Keep every handwritten file at or below 1,000 lines.
- Use TDD, then commit and push every task.

---

### Task 1: Incremental center-first sector scheduler

**Files:**
- Create: `scripts/application/streaming/sector_request.gd`
- Reuse: `scripts/application/streaming/sector_ring_iterator.gd`
- Create: `scripts/application/streaming/sector_request_scheduler.gd`
- Create: `tests/application/streaming/test_sector_request_scheduler.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: immutable `SectorRequest(epoch: int, coordinate: SectorCoordinate, priority: int)`.
- Produces: `SectorRequestScheduler.reconcile(center, radii, active_keys, cached_keys, profile) -> int`.
- Produces: `pop_next() -> SectorRequest`, `mark_running(request)`, `complete(request)`, `is_current(request)`, `pending_count()`, `running_count()`.

- [ ] **Step 1: Write failing bounded-order tests**

```gdscript
func run() -> void:
    var scheduler = SectorRequestScheduler.new()
    var profile = Settings.performance_profile(&"low").duplicate(true)
    profile.max_pending_requests = 4
    profile.max_detailed_sectors = 9
    var epoch = scheduler.reconcile(
        Coordinate.new(10, -3), Vector2i(10000, 10000), {}, {}, profile
    )
    assert_equal(scheduler.pending_count(), 4, "queue is bounded")
    var first = scheduler.pop_next()
    assert_equal(first.coordinate.key(), "10:-3", "center is first")
    assert_equal(first.epoch, epoch, "request carries current epoch")
    assert_true(scheduler.pending_count() <= 4, "refill remains bounded")
```

Add cases for rectangular clipping, active/cached skips, no duplicates, exactly
`max_detailed_sectors` admitted, deterministic tie order and old-epoch rejection.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_request_scheduler.gd'
```

Expected: FAIL because scheduler types are missing.

- [ ] **Step 3: Implement the request record**

```gdscript
class_name SectorRequest
extends RefCounted

var epoch: int
var coordinate: SectorCoordinate
var priority: int

func _init(request_epoch: int, sector: SectorCoordinate, request_priority: int) -> void:
    assert(request_epoch > 0 and sector != null and request_priority >= 0)
    epoch = request_epoch
    coordinate = sector.offset(0, 0)
    priority = request_priority
```

- [ ] **Step 4: Reuse the existing lazy ring iterator**

Use the existing `SectorRingIterator` as the scheduler's only coordinate source.
Do not create another ring implementation or change its deterministic contract:
increasing Chebyshev distance, then `y`, then `x`. It already clips rectangular
radii, stores O(1) cursor state and returns `null` after exhaustion.

The scheduler may wrap coordinates with epoch and priority metadata, but must not
allocate a complete coverage Array or alter iterator ordering. Extend the
iterator's focused tests only if the scheduler needs a new general-purpose
iterator contract.

- [ ] **Step 5: Implement bounded refill**

`SectorRequestScheduler._refill()` scans the iterator only until the pending cap,
iterator exhaustion or admitted cap. Keys in active, cached, pending or running
are skipped. `reconcile()` increments epoch and resets only scheduling state;
`is_current()` compares the immutable request epoch.

- [ ] **Step 6: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_request_scheduler.gd'
./tools/run_godot_tests.ps1
```

Expected: PASS without a large allocation at radii `10000,10000`.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/application/streaming tests/application/streaming/test_sector_request_scheduler.gd tests/test_runner.gd
git commit -m "feat: schedule bounded sector requests"
git push
```

### Task 2: Immutable in-memory scientific catalog snapshot

**Files:**
- Create: `scripts/application/catalog/catalog_runtime_snapshot.gd`
- Modify: `scripts/application/ports/scientific_catalog_repository.gd`
- Modify: `scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd`
- Modify: `tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd`
- Modify: `tests/adapters/persistence/test_production_catalog.gd`

**Interfaces:**
- Produces: `ScientificCatalogRepository.runtime_snapshot() -> CatalogRuntimeSnapshot`.
- Snapshot implements `metadata()`, `systems_in_bounds(Rect2)`, `system_composition(StringName)` and never touches SQLite after construction.

- [ ] **Step 1: Write failing production snapshot tests**

```gdscript
var repository = Repository.new()
assert_true(repository.open(), "production catalog opens")
var snapshot = repository.runtime_snapshot()
repository.close()
assert_true(snapshot != null, "atomic runtime snapshot loads")
assert_equal(snapshot.metadata().catalog_version, 1, "metadata survives close")
assert_equal(snapshot.system_composition(&"catalog:sol").planets.size(), 8, "Sol survives close")
assert_equal(snapshot.system_composition(&"catalog:unknown"), null, "unknown remains absent")
assert_equal(
    snapshot.systems_in_bounds(Rect2(8140.0, -10.0, 20.0, 20.0))[0].id,
    &"catalog:sol",
    "anchor index survives close"
)
```

Also assert returned Arrays and compositions cannot mutate snapshot storage and a
forced query failure returns `null`, not a partial snapshot.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
```

Expected: FAIL because `runtime_snapshot` is missing.

- [ ] **Step 3: Implement the snapshot adapter**

```gdscript
class_name CatalogRuntimeSnapshot
extends "res://scripts/application/ports/scientific_catalog_repository.gd"

var _metadata
var _anchors: Array
var _compositions: Dictionary

func _init(catalog_metadata, anchors: Array, compositions: Dictionary) -> void:
    assert(catalog_metadata != null)
    _metadata = catalog_metadata
    _anchors = anchors.duplicate()
    _compositions = compositions.duplicate()

func metadata(): return _metadata
func systems_in_bounds(bounds: Rect2) -> Array:
    return _anchors.filter(func(anchor):
        var point := anchor.map_position()
        return point.x >= bounds.position.x and point.y >= bounds.position.y \
            and point.x < bounds.end.x and point.y < bounds.end.y
    )
func system_composition(system_id: StringName):
    return _compositions.get(system_id)
func runtime_snapshot(): return self
```

The constructor must validate unique anchor IDs and exact composition IDs. Public
arrays are duplicated; existing domain records already expose defensive data.

- [ ] **Step 4: Build the snapshot atomically in SQLite adapter**

Add a bound-free, read-only query returning all anchors ordered by ID. Copy its
rows immediately. For every anchor ID call the existing atomic
`system_composition`. If any query or composition fails, return `null` immediately
without constructing the snapshot. Preserve the first SQLite error.

- [ ] **Step 5: Verify catalog hash and tests**

```powershell
$before=(Get-FileHash data/catalog/zodiakos_catalog.sqlite -Algorithm SHA256).Hash
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_production_catalog.gd'
$after=(Get-FileHash data/catalog/zodiakos_catalog.sqlite -Algorithm SHA256).Hash
if($before -ne $after){ throw 'Catalog changed while creating snapshot' }
./tools/run_godot_tests.ps1
```

Expected: PASS and equal hashes.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/application/catalog/catalog_runtime_snapshot.gd scripts/application/ports/scientific_catalog_repository.gd scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd tests/adapters/persistence/test_production_catalog.gd
git commit -m "feat: snapshot scientific catalog in memory"
git push
```

### Task 3: Reusable WorkerThreadPool task executor

**Files:**
- Create: `scripts/application/async/task_executor.gd`
- Create: `scripts/adapters/godot/worker_thread_task_executor.gd`
- Create: `tests/adapters/godot/test_worker_thread_task_executor.gd`
- Create: `tests/fixtures/manual_task_executor.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `submit(job: Callable, high_priority := false) -> int`, `is_completed(token: int) -> bool`, `take_result(token: int) -> Variant`, `active_count() -> int`, `set_capacity(capacity: int)`, `shutdown()`.
- A result can be taken exactly once; shutdown waits every submitted Godot task.
- One executor is shared by sector, aggregate and composition services so its capacity is the global profile job cap.

- [ ] **Step 1: Write failing executor lifecycle tests**

```gdscript
var executor = WorkerThreadTaskExecutor.new(2)
var token := executor.submit(func(): return 42)
while not executor.is_completed(token): OS.delay_msec(1)
assert_equal(executor.take_result(token), 42, "worker result returns")
assert_equal(executor.active_count(), 0, "taking result releases task")
executor.set_capacity(1)
var occupied := executor.submit(func(): return 7)
assert_equal(executor.submit(func(): return 8), -1, "global capacity rejects excess work")
while not executor.is_completed(occupied): OS.delay_msec(1)
assert_equal(executor.take_result(occupied), 7, "capacity slot is released")
executor.shutdown()
assert_equal(executor.submit(func(): return 1), -1, "shutdown rejects work")
```

Use a bounded polling deadline of two seconds so the suite cannot hang.

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot/test_worker_thread_task_executor.gd'
```

Expected: FAIL because executor is missing.

- [ ] **Step 3: Implement the port and production adapter**

The adapter validates a positive capacity, assigns its own monotonically increasing token, stores
`token -> WorkerThreadPool task_id`, and captures the callable result under a
`Mutex`. `is_completed` delegates to `WorkerThreadPool.is_task_completed`.
`take_result` first calls `wait_for_task_completion`, then removes task/result
state. `submit` returns `-1` when global capacity is full. `set_capacity` affects
new submissions without canceling active work. `shutdown` stops acceptance and
waits every remaining task before clearing.

```gdscript
func submit(job: Callable, high_priority := false) -> int:
    if _shutting_down or _tasks.size() >= _capacity: return -1
    var token := _next_token
    _next_token += 1
    var action := func():
        var value = job.call()
        _mutex.lock()
        _results[token] = value
        _mutex.unlock()
    var task_id := WorkerThreadPool.add_task(action, high_priority)
    _tasks[token] = task_id
    return token
```

- [ ] **Step 4: Implement deterministic manual executor fixture**

The fixture enforces the same capacity, queues callables and exposes `complete_next()` and
`complete_token(token)` so controller tests can choose completion order without
real timing.

- [ ] **Step 5: Run focused/full tests and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot/test_worker_thread_task_executor.gd'
./tools/run_godot_tests.ps1
git add scripts/application/async scripts/adapters/godot/worker_thread_task_executor.gd tests/adapters/godot/test_worker_thread_task_executor.gd tests/fixtures/manual_task_executor.gd tests/test_runner.gd
git commit -m "feat: execute bounded background tasks"
git push
```

Expected: PASS and clean shutdown.

### Task 4: Asynchronous sector generation service

**Files:**
- Create: `scripts/application/streaming/sector_job_result.gd`
- Create: `scripts/application/streaming/async_sector_generator.gd`
- Create: `tests/application/streaming/test_async_sector_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: sector source with `generate_sector(SectorCoordinate)`, `TaskExecutor`, `SectorRequest`.
- Produces: `submit(request) -> bool`, `collect_completed(limit: int) -> Array[SectorJobResult]`, `active_count()`, `stop_accepting()`, `drain_owned_tasks()`.
- The service borrows the shared executor; it never shuts the executor down.

- [ ] **Step 1: Write failing async service tests with manual executor**

Cover global executor rejection, result/request association, reverse completion order, null
result as explicit failure and stopping/draining owned work. The service must not decide relevance;
the controller owns that policy.

```gdscript
var manual = ManualTaskExecutor.new(2)
var source = SectorSourceSpy.new()
var service = AsyncSectorGenerator.new(source, manual)
assert_true(service.submit(_request(1, 0, 0)), "first job accepted")
assert_true(service.submit(_request(1, 1, 0)), "second job accepted")
assert_true(not service.submit(_request(1, 2, 0)), "job cap enforced")
manual.complete_token(2)
assert_equal(service.collect_completed(1)[0].request.coordinate.key(), "1:0", "completion order preserved")
```

- [ ] **Step 2: Run RED, implement and run GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_async_sector_generator.gd'
```

Implement token-to-request tracking. `submit` returns false without recording a
request when the shared executor returns `-1`. `collect_completed` scans only active tokens,
takes at most `limit`, and returns `SectorJobResult(request, sector, error)`.
Repeat the command; expected PASS.

- [ ] **Step 3: Run full suite and commit**

```powershell
./tools/run_godot_tests.ps1
git add scripts/application/streaming/sector_job_result.gd scripts/application/streaming/async_sector_generator.gd tests/application/streaming/test_async_sector_generator.gd tests/test_runner.gd
git commit -m "feat: generate galaxy sectors asynchronously"
git push
```

### Task 5: Integrate bounded async streaming into the demo

**Files:**
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Controller consumes: source, view, initial position, `PerformanceProfile`, optional `TaskExecutor`.
- Controller produces: `set_detail_enabled(bool)`, `set_profile(profile)`, bounded stats and clean `shutdown()`.
- Demo creates `CatalogRuntimeSnapshot`, closes SQLite, then constructs generator/source from snapshot.

- [ ] **Step 1: Rewrite controller tests before production code**

With `ManualTaskExecutor`, assert:

- no synchronous `generate_sector` during `update_view`;
- pending count never exceeds profile;
- active jobs never exceed profile;
- completed current results enter cache and view on main-thread `process_pending`;
- stale results may cache but never materialize;
- cache hit materializes without a generator call;
- a current procedural failure is retried exactly once, and a second failure is
  exposed through controller stats without caching or materializing partial data;
- stale, canceled and catalog-backed failures are never retried;
- `set_detail_enabled(false)` clears pending and submits nothing;
- shutdown drains executor and prevents callbacks.

- [ ] **Step 2: Run focused test and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: FAIL against the synchronous controller.

- [ ] **Step 3: Implement controller orchestration**

The demo creates one `WorkerThreadTaskExecutor` using the effective profile's
`max_concurrent_jobs` and lends it to sector, aggregate and composition services.
The controller does not own or close it. `_process` must perform, in order:

1. collect completed jobs up to the configured completion cap;
2. insert valid sectors in `SectorCache`;
3. materialize only current/relevant sectors while elapsed application time is
   below `profile.main_thread_budget_ms`;
4. submit center-first requests while the shared executor accepts work;
5. emit stats only when changed.

Do not call `generator.generate_sector` directly in the controller.
Use cache key `"%d:%s" % [generator.identity.value, coordinate.key()]`; expose
coordinate-only cached keys to the scheduler for the current identity. Profile
changes resize the LRU immediately and call `executor.set_capacity` once through
the demo-level owner.

Track procedural attempts by immutable `(identity, coordinate, epoch)` request
key. The first current failure is resubmitted only while the coordinate remains
relevant. Clear attempt state on success, staleness or cancellation. The second
failure increments the error metric and leaves both cache and view unchanged.
Catalog failures are terminal because the runtime snapshot is authoritative.

- [ ] **Step 4: Switch demo startup to atomic snapshot**

After validation, call `runtime_snapshot()`. If it is null, show one catalog error.
If valid, close the SQLite repository immediately and pass the snapshot to
`UniverseGenerator` and `LoadGalaxySector`. Update the lifecycle test to assert
the database is closed while navigation and Sol loading still work.

- [ ] **Step 5: Run focused, full, catalog and smoke tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

Expected: PASS, `CATALOG VALID`, smoke exit `0`, no orphan-worker errors.

Shutdown order is controller/services stop accepting -> each service drains/takes
its owned tokens -> demo calls shared executor `shutdown()` exactly once.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/adapters/godot_view/sector_stream_controller.gd scripts/demo/infinite_star_map_demo.gd tests/adapters/godot_view/test_sector_streaming.gd tests/demo/test_infinite_star_map_demo.gd
git commit -m "feat: stream bounded sectors in background"
git push
```

## Plan 2 Completion Gate

Run a scripted zoom calculation at `30000` and assert the scheduler holds no more
than the active profile's pending/detailed caps. Run the full suite, catalog
validation and a 30-second headless smoke. Verify the production SQLite hash is
unchanged and every WorkerThreadPool task is released during shutdown.
