# Adaptive Performance Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed performance profiles, deterministic LOD selection and reusable bounded LRU caches without changing the canonical universe.

**Architecture:** Presentation budgets live in typed resources embedded in `game_settings.tres`. Pure application services select LOD and cache immutable domain results; none of these values enter `UniverseIdentity`.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, native Windows PowerShell, existing custom test runner.

## Global Constraints

- Develop and validate on native Windows; do not use WSL.
- Keep every handwritten file at or below 1,000 lines.
- Use TDD for every task.
- Keep domain and application code independent from SceneTree, SQLite and rendering.
- Put all tunable defaults in `config/game_settings.tres` with typed Inspector fields and validation.
- Performance settings must not alter `UniverseIdentity`, system IDs, positions, names or composition.
- Commit and push after every completed task.

---

### Task 1: Typed performance profiles in central settings

**Files:**
- Create: `scripts/config/performance_profile.gd`
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Modify: `tests/config/test_game_settings.gd`

**Interfaces:**
- Produces: `PerformanceProfile.validation_errors() -> PackedStringArray`.
- Produces: `GameSettings.performance_profile(profile_id: StringName) -> PerformanceProfile`.
- Produces: embedded profiles `low`, `medium`, `high`, `ultra` and automatic-quality defaults.

- [ ] **Step 1: Write failing configuration tests**

Add assertions for all four profiles, exact defaults from the spec, lookup by ID,
invalid thresholds/capacities and automatic defaults:

```gdscript
assert_equal(Settings.performance_default_profile, &"auto", "automatic is default")
assert_equal(Settings.performance_target_fps, 60.0, "automatic target")
var medium = Settings.performance_profile(&"medium")
assert_equal(medium.detail_max_zoom, 400.0, "medium detail threshold")
assert_equal(medium.max_detailed_sectors, 256, "medium detailed cap")
assert_equal(medium.max_concurrent_jobs, 2, "medium worker cap")
assert_equal(medium.sector_cache_capacity, 128, "medium sector cache")
assert_equal(Settings.performance_profile(&"unknown"), null, "unknown profile")
var invalid = medium.duplicate(true)
invalid.detail_max_zoom = invalid.cluster_max_zoom
assert_true(
    invalid.validation_errors().has("performance zoom order must be detail < cluster"),
    "profile rejects inverted LOD thresholds"
)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: FAIL because the profile type and fields do not exist.

- [ ] **Step 3: Implement the typed resource**

Create:

```gdscript
class_name PerformanceProfile
extends Resource

@export var profile_id: StringName
@export var detail_max_zoom: float
@export var cluster_max_zoom: float
@export_range(0.0, 0.49) var lod_hysteresis_ratio: float
@export var max_detailed_sectors: int
@export var max_pending_requests: int
@export var max_concurrent_jobs: int
@export var main_thread_budget_ms: float
@export var sector_cache_capacity: int
@export var composition_cache_capacity: int
@export var cluster_point_budget: int
@export var star_mesh_quality: int
@export var effects_enabled: bool

func validation_errors() -> PackedStringArray:
    var errors := PackedStringArray()
    if profile_id.is_empty(): errors.append("performance profile id must not be empty")
    if detail_max_zoom <= 0.0 or detail_max_zoom >= cluster_max_zoom:
        errors.append("performance zoom order must be detail < cluster")
    if lod_hysteresis_ratio < 0.0 or lod_hysteresis_ratio >= 0.5:
        errors.append("performance LOD hysteresis must satisfy 0 <= value < 0.5")
    for pair in [
        ["max_detailed_sectors", max_detailed_sectors],
        ["max_pending_requests", max_pending_requests],
        ["sector_cache_capacity", sector_cache_capacity],
        ["composition_cache_capacity", composition_cache_capacity],
        ["cluster_point_budget", cluster_point_budget],
    ]:
        if pair[1] < 0: errors.append("%s must be nonnegative" % pair[0])
    if max_concurrent_jobs < 1:
        errors.append("max_concurrent_jobs must be positive")
    if main_thread_budget_ms <= 0.0:
        errors.append("main_thread_budget_ms must be positive")
    if star_mesh_quality < 1:
        errors.append("star_mesh_quality must be positive")
    return errors
```

Add typed profile fields and automatic defaults to `GameSettings`. Implement
lookup with an exhaustive match and append every nested validation error with a
profile prefix. Add these exact global fields and defaults:

```gdscript
@export var performance_default_profile: StringName = &"auto"
@export var performance_target_fps: float = 60.0
@export var performance_auto_sample_seconds: float = 2.0
@export var performance_auto_downgrade_seconds: float = 3.0
@export var performance_auto_upgrade_seconds: float = 10.0
@export var performance_auto_upgrade_ratio: float = 0.85
@export var performance_auto_cooldown_seconds: float = 5.0
@export var performance_selection_tolerance_pixels: float = 12.0
@export var performance_max_completions_per_frame: int = 8
@export var performance_metrics_enabled: bool = true
```

Validate positive durations/FPS/tolerance/completion count, upgrade ratio strictly
between zero and one, a supported default ID, unique nested profile IDs and exact
IDs `low`, `medium`, `high`, `ultra`. Use hysteresis `0.10` for every initial
profile, mesh qualities `1,2,3,4`, effects disabled only on Low, and embed all four
subresources in `game_settings.tres` using the exact numeric table in the approved
spec.

- [ ] **Step 4: Verify identity exclusion explicitly**

Extend `tests/domain/universe/test_universe_generator.gd` or the existing identity
test so mutating only a duplicated performance profile leaves
`UniverseIdentity.value` unchanged:

```gdscript
var changed = Settings.duplicate(true)
changed.performance_medium.max_pending_requests += 1
assert_equal(
    _identity_for(changed).value,
    _identity_for(Settings).value,
    "presentation budgets are excluded from universe identity"
)
```

- [ ] **Step 5: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1
```

Expected: both PASS without stderr.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/config/performance_profile.gd scripts/config/game_settings.gd config/game_settings.tres tests/config/test_game_settings.gd tests/domain/universe/test_universe_generator.gd
git commit -m "feat: configure adaptive performance profiles"
git push
```

### Task 2: Pure galaxy LOD policy with hysteresis

**Files:**
- Create: `scripts/application/projections/galaxy_lod_policy.gd`
- Create: `tests/application/projections/test_galaxy_lod_policy.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `PerformanceProfile`.
- Produces: `level_for(zoom: float, previous: StringName, profile: PerformanceProfile) -> StringName`.
- LOD values: `&"overview"`, `&"cluster"`, `&"detail"`.

- [ ] **Step 1: Write failing threshold and hysteresis tests**

```gdscript
func run() -> void:
    var policy = GalaxyLodPolicy.new()
    var profile = Settings.performance_profile(&"medium")
    assert_equal(policy.level_for(100.0, &"", profile), &"detail", "near zoom")
    assert_equal(policy.level_for(1000.0, &"", profile), &"cluster", "middle zoom")
    assert_equal(policy.level_for(7000.0, &"", profile), &"overview", "far zoom")
    var upper_detail := profile.detail_max_zoom * (1.0 + profile.lod_hysteresis_ratio)
    assert_equal(policy.level_for(upper_detail - 0.1, &"detail", profile), &"detail", "detail holds")
    assert_equal(policy.level_for(upper_detail + 0.1, &"detail", profile), &"cluster", "detail exits")
```

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_galaxy_lod_policy.gd'
```

Expected: FAIL because the policy script is missing.

- [ ] **Step 3: Implement the policy**

```gdscript
class_name GalaxyLodPolicy
extends RefCounted

func level_for(zoom: float, previous: StringName, profile: PerformanceProfile) -> StringName:
    assert(profile != null and profile.validation_errors().is_empty())
    var detail_enter := profile.detail_max_zoom * (1.0 - profile.lod_hysteresis_ratio)
    var detail_exit := profile.detail_max_zoom * (1.0 + profile.lod_hysteresis_ratio)
    var overview_enter := profile.cluster_max_zoom * (1.0 + profile.lod_hysteresis_ratio)
    var overview_exit := profile.cluster_max_zoom * (1.0 - profile.lod_hysteresis_ratio)
    match previous:
        &"detail":
            return &"detail" if zoom <= detail_exit else (&"cluster" if zoom < overview_enter else &"overview")
        &"overview":
            return &"overview" if zoom >= overview_exit else (&"detail" if zoom < detail_enter else &"cluster")
        &"cluster":
            if zoom < detail_enter: return &"detail"
            if zoom > overview_enter: return &"overview"
            return &"cluster"
    if zoom <= profile.detail_max_zoom: return &"detail"
    if zoom <= profile.cluster_max_zoom: return &"cluster"
    return &"overview"
```

- [ ] **Step 4: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_galaxy_lod_policy.gd'
./tools/run_godot_tests.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/application/projections/galaxy_lod_policy.gd tests/application/projections/test_galaxy_lod_policy.gd tests/test_runner.gd
git commit -m "feat: select galactic levels of detail"
git push
```

### Task 3: Reusable bounded LRU cache

**Files:**
- Create: `scripts/application/cache/lru_cache.gd`
- Create: `tests/application/cache/test_lru_cache.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `LruCache.new(capacity: int)`.
- Produces: `put(key: Variant, value: Variant) -> Variant` (evicted key or null), `get_value(key: Variant)`, `has(key: Variant)`, `erase(key: Variant)`, `resize(capacity: int) -> Array` (evicted keys), `clear()`, `size()`, `keys_most_recent_first()`.
- Null values are rejected so `null` remains the cache-miss result.

- [ ] **Step 1: Write failing LRU tests**

```gdscript
func run() -> void:
    var cache = LruCache.new(2)
    cache.put("a", 1)
    cache.put("b", 2)
    assert_equal(cache.get_value("a"), 1, "hit returns value")
    assert_equal(cache.put("c", 3), "b", "put reports evicted key")
    assert_true(cache.has("a"), "hit promotes entry")
    assert_true(not cache.has("b"), "least recent entry is evicted")
    assert_equal(cache.keys_most_recent_first(), ["c", "a"], "order is exposed defensively")
    cache.resize(0)
    assert_equal(cache.size(), 0, "zero capacity clears and disables cache")
```

- [ ] **Step 2: Run and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/cache/test_lru_cache.gd'
```

Expected: FAIL because the cache does not exist.

- [ ] **Step 3: Implement minimal deterministic LRU behavior**

```gdscript
class_name LruCache
extends RefCounted

var _capacity: int
var _values := {}
var _order := []

func _init(capacity: int) -> void:
    assert(capacity >= 0)
    _capacity = capacity

func put(key: Variant, value: Variant) -> Variant:
    assert(value != null, "LRU cache does not store null values")
    if _capacity == 0: return null
    _values[key] = value
    _promote(key)
    var evicted = null
    while _order.size() > _capacity:
        evicted = _order.pop_back()
        _values.erase(evicted)
    return evicted

func get_value(key: Variant) -> Variant:
    if not _values.has(key): return null
    _promote(key)
    return _values[key]

func has(key: Variant) -> bool: return _values.has(key)
func size() -> int: return _values.size()
func keys_most_recent_first() -> Array: return _order.duplicate()
func erase(key: Variant) -> void:
    _values.erase(key)
    _order.erase(key)
func clear() -> void:
    _values.clear()
    _order.clear()
func resize(capacity: int) -> Array:
    assert(capacity >= 0)
    _capacity = capacity
    var evicted := []
    while _order.size() > _capacity:
        var key = _order.pop_back()
        _values.erase(key)
        evicted.append(key)
    return evicted
func _promote(key: Variant) -> void:
    _order.erase(key)
    _order.push_front(key)
```

- [ ] **Step 4: Add defensive and edge coverage**

Test overwrite, erase, clear, resizing up/down, unhashable-key rejection from
Godot itself and mutation of the returned key list not affecting the cache.

- [ ] **Step 5: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/cache/test_lru_cache.gd'
./tools/run_godot_tests.ps1
```

Expected: PASS.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/application/cache/lru_cache.gd tests/application/cache/test_lru_cache.gd tests/test_runner.gd
git commit -m "feat: cache bounded universe results"
git push
```

### Task 4: Plan 1 integration gate

**Files:**
- Modify only if a gate exposes a defect in Plan 1 files.

**Interfaces:**
- Verifies: profile configuration, LOD policy, cache and identity exclusion together.

- [ ] **Step 1: Run focused suites and full suite**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_galaxy_lod_policy.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/cache/test_lru_cache.gd'
./tools/run_godot_tests.ps1
```

Expected: all PASS without stderr.

- [ ] **Step 2: Run catalog and Godot smoke gates**

```powershell
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 5
```

Expected: `CATALOG VALID`, `TESTS PASSED`, smoke exit code `0`.

- [ ] **Step 3: Verify configuration-only mutations preserve signatures**

Use the automated identity test and confirm it compares baseline against all four
profiles. Do not accept a test that only compares two profile resources without
constructing `UniverseIdentity`.

- [ ] **Step 4: Commit and push any gate fix**

If no fix is required, record the gate as verification-only. If a fix is required,
return to the rejected task, apply TDD there and use that task's explicit staging
list and commit procedure; do not create an unscoped gate commit.
