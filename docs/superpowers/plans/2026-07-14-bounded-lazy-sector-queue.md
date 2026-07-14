# Bounded Lazy Sector Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep zoom-dependent coverage, including scale ten at maximum zoom, while replacing eager full-area coordinate arrays with a deterministic ring iterator and a 256-coordinate pending window.

**Architecture:** A pure `SectorRingIterator` owns O(1) enumeration state and preserves the existing distance/y/x order. `SectorStreamController` replaces the iterator only when the center or effective load radii change, keeps a configured pending window, and refills it after the existing per-frame generation batch.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, native Windows PowerShell, existing custom Godot test runner.

## Global Constraints

- Develop and validate on native Windows; do not use WSL.
- Keep handwritten files at or below 1,000 lines.
- Use TDD and observe focused failures before production changes.
- Preserve `stream_render_scale = 10.0`, `stream_load_margin = 0`, `stream_unload_margin = 0`.
- Preserve the user's current Inspector value `stream_max_aspect_ratio = 1.0`.
- Reject nonfinite `stream_render_scale` as well as values below `1.0`.
- Set `stream_max_pending_sectors = 256` and require it to be positive.
- Never cap final scale-derived coverage; cap only coordinates waiting in memory.
- Preserve exact center-first ordering by Chebyshev distance, then y, then x.
- Do not change `UniverseIdentity`, canonical generation, SQLite or renderer behavior.
- Keep sector generation synchronous and limited by `stream_sectors_per_frame` in this phase.
- Commit and push after each task; never stage unrelated work.

---

### Task 1: Reusable ring iterator and pending-cap configuration

**Files:**
- Create: `scripts/application/streaming/sector_ring_iterator.gd`
- Create: `tests/application/streaming/test_sector_ring_iterator.gd`
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`
- Modify: `docs/superpowers/specs/2026-07-13-central-game-settings-design.md`
- Modify: `docs/superpowers/specs/2026-07-13-stream-render-scale-design.md`
- Modify: `docs/superpowers/plans/2026-07-13-bounded-async-sector-streaming.md`

**Interfaces:**
- `SectorRingIterator.new(center: SectorCoordinate, radii: Vector2i)` copies center and radii.
- `next_coordinate()` returns the next `SectorCoordinate` or `null` after exhaustion.
- `is_exhausted() -> bool` remains true after exhaustion.
- `GameSettings.stream_max_pending_sectors: int` is a positive Map Streaming Inspector field.

- [ ] **Step 1: Write failing configuration and identity tests**

Add production assertions to `tests/config/test_game_settings.gd`:

```gdscript
assert_equal(Settings.stream_max_aspect_ratio, 1.0, "stream maximum aspect")
assert_equal(Settings.stream_max_pending_sectors, 256, "stream pending cap")
```

Add validation:

```gdscript
_assert_validation_error(
	&"stream_max_pending_sectors",
	0,
	"stream_max_pending_sectors must be positive"
)

_assert_validation_error(
	&"stream_render_scale",
	NAN,
	"stream_render_scale must be finite and at least 1"
)
_assert_validation_error(
	&"stream_render_scale",
	INF,
	"stream_render_scale must be finite and at least 1"
)
```

Update the existing `0.99` scale case to expect the same unified error:

```text
stream_render_scale must be finite and at least 1
```

Register and add to `tests/domain/universe/test_universe_generator.gd`:

```gdscript
func _test_stream_pending_cap_does_not_version_universe() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var baseline = Identity.new(101, 7, metadata, Settings).value
	var changed = Settings.duplicate(true)
	changed.stream_max_pending_sectors += 1
	assert_equal(
		Identity.new(101, 7, metadata, changed).value,
		baseline,
		"pending presentation cap stays outside universe identity"
	)
```

Preserve the zoom-dependent production extreme-wide expectation in
`tests/application/projections/test_visible_sector_projection.gd`:

```gdscript
Vector2i(14, 14)
```

This records the user-approved maximum aspect `1.0` and the zoom-dependent scale
already implemented before this plan executes.

Update the aspect-dependent integration expectations in the same commit:

```gdscript
# tests/adapters/godot_view/test_sector_streaming.gd, injected scale 1
controller.load_radii == Vector2i(5, 5)
controller.pending.size() == 121

# tests/demo/test_infinite_star_map_demo.gd, production scale 10 at 32:9
stream.load_radii == Vector2i(14, 14)
```

- [ ] **Step 2: Write the failing iterator suite**

Create `tests/application/streaming/test_sector_ring_iterator.gd`:

```gdscript
extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Iterator = preload("res://scripts/application/streaming/sector_ring_iterator.gd")


func run() -> void:
	_test_exact_first_two_rings()
	_test_rectangular_clipping_and_total()
	_test_zero_radii_and_stable_exhaustion()
	_test_center_is_defensively_copied()


func _test_exact_first_two_rings() -> void:
	var iterator = Iterator.new(Coordinate.new(4, -2), Vector2i(2, 2))
	var keys := []
	for _index in 25:
		keys.append(iterator.next_coordinate().key())
	assert_equal(keys, [
		"4:-2",
		"3:-3", "4:-3", "5:-3", "3:-2", "5:-2", "3:-1", "4:-1", "5:-1",
		"2:-4", "3:-4", "4:-4", "5:-4", "6:-4",
		"2:-3", "6:-3", "2:-2", "6:-2", "2:-1", "6:-1",
		"2:0", "3:0", "4:0", "5:0", "6:0",
	], "center and first two rings retain distance/y/x order")
	var unique := {}
	for key in keys:
		unique[key] = true
	assert_equal(unique.size(), 25, "coordinates are unique")


func _test_rectangular_clipping_and_total() -> void:
	var wide := _drain(Iterator.new(Coordinate.new(), Vector2i(3, 1)))
	assert_equal(wide.size(), 21, "wide rectangle emits seven by three coordinates")
	assert_equal(wide[0], "0:0", "wide rectangle remains center-first")
	var tall := _drain(Iterator.new(Coordinate.new(), Vector2i(1, 3)))
	assert_equal(tall.size(), 21, "tall rectangle emits three by seven coordinates")


func _test_zero_radii_and_stable_exhaustion() -> void:
	var iterator = Iterator.new(Coordinate.new(2, 7), Vector2i.ZERO)
	assert_equal(iterator.next_coordinate().key(), "2:7", "zero radius emits center")
	assert_equal(iterator.next_coordinate(), null, "zero radius then exhausts")
	assert_true(iterator.is_exhausted(), "iterator exposes exhaustion")
	assert_equal(iterator.next_coordinate(), null, "exhaustion remains stable")


func _test_center_is_defensively_copied() -> void:
	var center = Coordinate.new(5, 6)
	var iterator = Iterator.new(center, Vector2i.ZERO)
	center.x = 99
	assert_equal(iterator.next_coordinate().key(), "5:6", "center mutation cannot alter iterator")


func _drain(iterator) -> Array:
	var keys := []
	while true:
		var coordinate = iterator.next_coordinate()
		if coordinate == null:
			return keys
		keys.append(coordinate.key())
	return keys
```

Register the suite in `tests/test_runner.gd` immediately after the visible
projection suite.

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_ring_iterator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: iterator suite cannot load the missing script; settings suite cannot
resolve the missing pending-cap field.

- [ ] **Step 4: Add the central pending cap**

In `scripts/config/game_settings.gd`, add after `stream_initial_load_radii`:

```gdscript
@export var stream_max_pending_sectors: int
```

In `_validate_streaming`, add:

```gdscript
_require_positive(errors, "stream_max_pending_sectors", stream_max_pending_sectors)
if is_nan(stream_render_scale) or is_inf(stream_render_scale) or stream_render_scale < 1.0:
	errors.append("stream_render_scale must be finite and at least 1")
```

Replace the existing scale-below-one validation rather than appending a second
error for the same field.

In `config/game_settings.tres`, preserve the current aspect change and add:

```text
stream_max_pending_sectors = 256
stream_max_aspect_ratio = 1.0
```

- [ ] **Step 5: Implement the O(1)-state ring iterator**

Create `scripts/application/streaming/sector_ring_iterator.gd`:

```gdscript
class_name SectorRingIterator
extends RefCounted

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")

var _center: SectorCoordinate
var _radii: Vector2i
var _maximum_radius: int
var _radius := 0
var _ring_y := 0
var _ring_x := 0
var _exhausted := false


func _init(center: SectorCoordinate, radii: Vector2i) -> void:
	assert(center != null, "Sector ring iterator requires a center")
	assert(radii.x >= 0 and radii.y >= 0, "Sector ring radii must be nonnegative")
	_center = center.offset(0, 0)
	_radii = radii
	_maximum_radius = maxi(radii.x, radii.y)


func next_coordinate():
	if _exhausted:
		return null
	while _radius <= _maximum_radius:
		var offset = _next_ring_offset()
		if offset == null:
			_advance_ring()
			continue
		if absi(offset.x) <= _radii.x and absi(offset.y) <= _radii.y:
			return _center.offset(offset.x, offset.y)
	_exhausted = true
	return null


func is_exhausted() -> bool:
	return _exhausted


func _next_ring_offset():
	if _ring_y > _radius:
		return null
	var offset := Vector2i(_ring_x, _ring_y)
	if _ring_y == -_radius or _ring_y == _radius:
		_ring_x += 1
		if _ring_x > _radius:
			_ring_y += 1
			_ring_x = -_radius
	elif _ring_x == -_radius:
		_ring_x = _radius
	else:
		_ring_y += 1
		_ring_x = -_radius
	return offset


func _advance_ring() -> void:
	_radius += 1
	_ring_y = -_radius
	_ring_x = -_radius
```

- [ ] **Step 6: Align docs and the future async plan**

In `docs/superpowers/specs/2026-07-13-central-game-settings-design.md`, preserve
the maximum aspect value `1.0` and add pending window `256` under map streaming.

In `docs/superpowers/specs/2026-07-13-stream-render-scale-design.md`, clarify
that render scale must be finite and at least `1.0`.

In `docs/superpowers/plans/2026-07-13-bounded-async-sector-streaming.md`, replace
its instruction to create `sector_ring_iterator.gd` with an instruction to reuse
and extend the existing `SectorRingIterator` without changing its deterministic
order.

- [ ] **Step 7: Run focused/full tests, commit and push**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_ring_iterator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1
git diff --check
git add scripts/application/streaming/sector_ring_iterator.gd tests/application/streaming/test_sector_ring_iterator.gd scripts/config/game_settings.gd config/game_settings.tres tests/config/test_game_settings.gd tests/domain/universe/test_universe_generator.gd tests/application/projections/test_visible_sector_projection.gd tests/adapters/godot_view/test_sector_streaming.gd tests/demo/test_infinite_star_map_demo.gd tests/test_runner.gd docs/superpowers/specs/2026-07-13-central-game-settings-design.md docs/superpowers/specs/2026-07-13-stream-render-scale-design.md docs/superpowers/plans/2026-07-13-bounded-async-sector-streaming.md
git commit -m "feat: enumerate sector coverage lazily"
git push
```

Expected: tests pass, the user aspect change is included intentionally, and only
Task 1 files are staged.

---

### Task 2: Bounded lazy controller integration

**Files:**
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Controller retains `pending`, `queued`, `update_center`, `update_view`, `process_pending`, signals and constructor.
- Controller adds private `_iterator`, `_refill_pending()` and reset-aware
  reconciliation only.
- `pending.size()` never exceeds `settings.stream_max_pending_sectors`.
- `VisibleSectorProjection` retains `load_radii`, `unload_radii`, `unload_coordinates`; eager `load_order` is removed.

- [ ] **Step 1: Write failing controller cap/refill tests**

Register these tests in `tests/adapters/godot_view/test_sector_streaming.gd` and
add:

```gdscript
func _test_production_maximum_zoom_uses_bounded_lazy_pending() -> void:
	var controller = Controller.new()
	var view = View.new()
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_view(1000.0, Vector2(1920.0, 1080.0))
	assert_equal(controller.load_radii, Vector2i(125, 125), "maximum zoom target")
	assert_equal(controller.pending.size(), 256, "pending stays at production cap")
	controller.process_pending(2)
	assert_equal(view.active_sector_count(), 2, "frame batch generates two sectors")
	assert_equal(controller.pending.size(), 256, "pending refills after batch")
	controller.free()
	view.free()


func _test_injected_pending_cap_and_zero_processing_limit() -> void:
	var custom = _unscaled_stream_settings()
	custom.stream_max_pending_sectors = 7
	var controller = Controller.new(custom)
	var view = View.new(custom)
	controller.configure(
		Generator.new(FakeRepository.new()),
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	assert_equal(controller.pending.size(), 7, "injected cap bounds initial pending")
	controller.process_pending(0)
	assert_equal(view.active_sector_count(), 0, "zero limit generates nothing")
	assert_equal(controller.pending.size(), 7, "zero limit retains bounded window")
	controller.free()
	view.free()
```

Update `_unscaled_stream_settings` to set
`stream_max_pending_sectors = 512`, preserving existing complete small-coverage
tests. Keep the dedicated cap test at `7`.

Extend `_test_view_update_reconciles_even_when_radii_are_unchanged` to capture
`pending` keys before the repeated view update and assert they remain identical,
while retaining its existing rebase assertion.

The maximum-aspect expectation is preserved atomically with the user setting in
Task 1: scale-one radii are `Vector2i(5, 5)` and complete coverage is `121` under
the injected cap `512`.

- [ ] **Step 2: Update demo maximum-zoom routing test**

Add to `tests/demo/test_infinite_star_map_demo.gd`:

```gdscript
func _test_maximum_zoom_routes_scaled_lazy_coverage() -> void:
	var demo = Demo.instantiate()
	var stream = demo.get_node("SectorStreamController")
	demo.get_node("MapCamera").size = 1000.0
	demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
	assert_equal(stream.load_radii, Vector2i(125, 125), "demo routes max zoom radii")
	assert_equal(stream.pending.size(), 256, "demo pending remains bounded")
	demo.free()
```

Register it in `run()`. Existing zoom `300` expectations remain valid; Task 1
preserves the approved aspect-one result `(14, 14)` for wide viewports.

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

Expected: pending cap/refill assertions fail because the controller still creates
the full eager Array.

- [ ] **Step 4: Migrate the controller to the iterator**

In `sector_stream_controller.gd`, preload and store:

```gdscript
const SectorRingIterator = preload(
	"res://scripts/application/streaming/sector_ring_iterator.gd"
)

var _iterator
```

Pass a reset flag from the two update paths:

```gdscript
# update_center, after assigning a genuinely new center
_reconcile_stream(true)

# update_view
var coverage_changed := next_load != load_radii
if coverage_changed:
	load_radii = next_load
	unload_radii = projection.unload_radii(load_radii)
_reconcile_stream(coverage_changed)
```

Change reconciliation to `_reconcile_stream(reset_schedule := false)`. Always
rebase/unload/emit as before, but replace scheduling state only when
`reset_schedule` is true or `_iterator` is null:

```gdscript
if reset_schedule or _iterator == null:
	pending.clear()
	queued.clear()
	_iterator = SectorRingIterator.new(center, load_radii)
	_refill_pending()
```

Add:

```gdscript
func _refill_pending() -> void:
	if _iterator == null:
		return
	var active_keys: Dictionary = view.active_keys()
	var scanned := 0
	while (
		pending.size() < settings.stream_max_pending_sectors
		and scanned < settings.stream_max_pending_sectors
	):
		var coordinate = _iterator.next_coordinate()
		if coordinate == null:
			return
		scanned += 1
		var key: String = coordinate.key()
		if active_keys.has(key) or queued.has(key):
			continue
		pending.append(coordinate)
		queued[key] = true
```

At the end of `process_pending`, call `_refill_pending()` before `_emit_stats()`.
Do not alter sector generation, view mutation, batch-size calculation or signals.

- [ ] **Step 5: Remove the eager API and migrate ordering tests**

Delete `VisibleSectorProjection.load_order`. Remove its eager ordering/filter tests
from `test_visible_sector_projection.gd`; equivalent exact ordering, clipping,
uniqueness and count are now owned by `test_sector_ring_iterator.gd`.

Run `rg -n "load_order\\(" scripts tests -g "*.gd"`; expected exit `1` with no
matches.

- [ ] **Step 6: Run focused, full, catalog and smoke verification**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_ring_iterator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
git diff --check
```

Expected: tests pass, catalog is valid, smoke exits `0`, no eager `load_order`
references remain and pending never exceeds configured capacity.

- [ ] **Step 7: Commit and push**

```powershell
git add scripts/adapters/godot_view/sector_stream_controller.gd scripts/application/projections/visible_sector_projection.gd tests/adapters/godot_view/test_sector_streaming.gd tests/application/projections/test_visible_sector_projection.gd tests/demo/test_infinite_star_map_demo.gd
git commit -m "perf: bound sector streaming queue"
git push
```
