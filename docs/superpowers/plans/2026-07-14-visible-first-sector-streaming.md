# Visible-First Sector Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Materialize every visible star-map sector before any sector from the expanded off-screen preload coverage.

**Architecture:** `VisibleSectorProjection` calculates an unscaled visible rectangle and the existing adaptive expanded rectangle. A new pure `PrioritizedSectorIterator` lazily composes two ring iterators, emitting the visible rectangle first and then the expanded rectangle without duplicates. `SectorStreamController` owns both radii and schedules through the prioritized iterator while preserving its bounded pending queue.

**Tech Stack:** Godot 4.7, typed GDScript, Compatibility renderer, native Windows PowerShell, custom headless Godot test runner.

## Global Constraints

- Work only in `C:\Users\phili\Documents\Zodiakos\.worktrees\star-map-engine` on branch `codex/star-map-engine`.
- Use native Windows PowerShell and Godot 4.7; do not use WSL.
- Keep each handwritten file below 1,000 lines.
- Keep generation deterministic and independent from rendering/UI.
- Keep `pending.size()` bounded by `stream_max_pending_sectors` (256 in production).
- Keep materialization bounded by `stream_sectors_per_frame` (2 in production).
- Do not change seed, system contents, SQLite, GPU, LOD, threads, or final expanded coverage.
- Do not stage the existing `config/game_settings.tres`, generated `.uid` files, or temporary SQLite DLL unless this plan explicitly changes them.

---

## File Structure

- Modify `scripts/application/projections/visible_sector_projection.gd`: calculate visible and expanded radii through one shared formula.
- Modify `tests/application/projections/test_visible_sector_projection.gd`: prove unscaled radii and containment.
- Create `scripts/application/streaming/prioritized_sector_iterator.gd`: lazily sequence visible and external coverage.
- Create `tests/application/streaming/test_prioritized_sector_iterator.gd`: prove strict phase order, uniqueness, total coverage, and exhaustion.
- Modify `tests/test_runner.gd`: register the new iterator suite.
- Modify `scripts/adapters/godot_view/sector_stream_controller.gd`: schedule using both radii.
- Modify `tests/adapters/godot_view/test_sector_streaming.gd`: prove controller materialization order and schedule reset behavior.

---

### Task 1: Separate visible and expanded projection radii

**Files:**
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Test: `tests/application/projections/test_visible_sector_projection.gd`

**Interfaces:**
- Consumes: `GameSettings.universe_sector_size`, stream aspect limits, load margin, camera zoom limits, and `stream_render_scale`.
- Produces: `visible_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i` and the existing `load_radii(...) -> Vector2i` with component-wise containment.

- [ ] **Step 1: Write the failing projection assertions**

Add before the unload assertions in `run()`:

```gdscript
	assert_equal(
		projection.visible_radii(300.0, 1.0),
		Vector2i(4, 4),
		"visible coverage does not use render amplification"
	)
	assert_equal(
		projection.visible_radii(300.0, 9.0 / 16.0),
		Vector2i(3, 4),
		"visible coverage preserves safe rectangular aspect"
	)
	var visible_at_max := projection.visible_radii(1000.0, 1.0)
	var load_at_max := projection.load_radii(1000.0, 1.0)
	assert_true(
		load_at_max.x >= visible_at_max.x and load_at_max.y >= visible_at_max.y,
		"expanded coverage contains visible coverage"
	)
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
```

Expected: FAIL because `VisibleSectorProjection.visible_radii` does not exist.

- [ ] **Step 3: Implement the shared projection formula**

Replace the radius calculation section with:

```gdscript
func visible_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	return _coverage_radii(orthographic_size, aspect_ratio, 1.0)


func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var visible := visible_radii(orthographic_size, aspect_ratio)
	var expanded := _coverage_radii(
		orthographic_size,
		aspect_ratio,
		_effective_render_scale(orthographic_size)
	)
	return Vector2i(maxi(expanded.x, visible.x), maxi(expanded.y, visible.y))


func _coverage_radii(
	orthographic_size: float,
	aspect_ratio: float,
	render_scale: float
) -> Vector2i:
	var scaled_half_height := maxf(orthographic_size, 0.0) * 0.5 * render_scale
	var safe_aspect_ratio := clampf(
		aspect_ratio,
		settings.stream_min_aspect_ratio,
		settings.stream_max_aspect_ratio
	)
	var scaled_half_width := scaled_half_height * safe_aspect_ratio
	return Vector2i(
		ceili(scaled_half_width / settings.universe_sector_size)
			+ settings.stream_load_margin,
		ceili(scaled_half_height / settings.universe_sector_size)
			+ settings.stream_load_margin
	)
```

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run the same focused command. Expected: `TESTS PASSED` and exit code 0.

- [ ] **Step 5: Commit the projection behavior**

```powershell
git add -- scripts/application/projections/visible_sector_projection.gd tests/application/projections/test_visible_sector_projection.gd
git commit -m "feat: separate visible stream coverage"
```

---

### Task 2: Add a lazy visible-first coverage iterator

**Files:**
- Create: `scripts/application/streaming/prioritized_sector_iterator.gd`
- Create: `tests/application/streaming/test_prioritized_sector_iterator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `SectorRingIterator.new(center, radii)`.
- Produces: `PrioritizedSectorIterator.new(center, visible_radii, load_radii)`, `next_coordinate()`, and `is_exhausted() -> bool`.

- [ ] **Step 1: Register and write the failing iterator suite**

Register this preload after `test_sector_ring_iterator.gd`:

```gdscript
	preload("res://tests/application/streaming/test_prioritized_sector_iterator.gd"),
```

Create `tests/application/streaming/test_prioritized_sector_iterator.gd`:

```gdscript
extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Iterator = preload(
	"res://scripts/application/streaming/prioritized_sector_iterator.gd"
)


func run() -> void:
	_test_visible_rectangle_precedes_external_coverage()
	_test_equal_radii_have_no_duplicates_and_exhaust_stably()
	_test_center_is_defensively_copied()


func _test_visible_rectangle_precedes_external_coverage() -> void:
	var keys := _drain(Iterator.new(
		Coordinate.new(),
		Vector2i(1, 0),
		Vector2i(2, 1)
	))
	assert_equal(
		keys.slice(0, 3),
		["0:0", "-1:0", "1:0"],
		"complete visible rectangle is emitted first"
	)
	assert_equal(keys[3], "-1:-1", "external phase starts after visible coverage")
	assert_equal(keys.size(), 15, "expanded five by three coverage is complete")
	var unique := {}
	for key in keys:
		unique[key] = true
	assert_equal(unique.size(), 15, "phases never repeat coordinates")


func _test_equal_radii_have_no_duplicates_and_exhaust_stably() -> void:
	var iterator = Iterator.new(Coordinate.new(), Vector2i(1, 1), Vector2i(1, 1))
	var keys := _drain(iterator)
	assert_equal(keys.size(), 9, "equal radii emit only the visible rectangle")
	assert_equal(iterator.next_coordinate(), null, "exhaustion remains stable")
	assert_true(iterator.is_exhausted(), "iterator exposes final exhaustion")


func _test_center_is_defensively_copied() -> void:
	var center = Coordinate.new(5, 6)
	var iterator = Iterator.new(center, Vector2i.ZERO, Vector2i.ZERO)
	center.x = 99
	assert_equal(iterator.next_coordinate().key(), "5:6", "center mutation is isolated")


func _drain(iterator) -> Array:
	var keys := []
	while true:
		var coordinate = iterator.next_coordinate()
		if coordinate == null:
			return keys
		keys.append(coordinate.key())
```

- [ ] **Step 2: Run the new suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_prioritized_sector_iterator.gd'
```

Expected: FAIL because `prioritized_sector_iterator.gd` does not exist.

- [ ] **Step 3: Implement the two-phase iterator**

Create:

```gdscript
class_name PrioritizedSectorIterator
extends RefCounted

const SectorRingIterator = preload(
	"res://scripts/application/streaming/sector_ring_iterator.gd"
)

var _center: SectorCoordinate
var _visible_radii: Vector2i
var _visible_iterator
var _expanded_iterator
var _visible_exhausted := false
var _exhausted := false


func _init(center: SectorCoordinate, visible_radii: Vector2i, load_radii: Vector2i) -> void:
	assert(center != null, "Prioritized iterator requires a center")
	assert(visible_radii.x >= 0 and visible_radii.y >= 0, "Visible radii must be nonnegative")
	assert(load_radii.x >= visible_radii.x and load_radii.y >= visible_radii.y, "Load radii must contain visible radii")
	_center = center.offset(0, 0)
	_visible_radii = visible_radii
	_visible_iterator = SectorRingIterator.new(_center, visible_radii)
	_expanded_iterator = SectorRingIterator.new(_center, load_radii)


func next_coordinate():
	if _exhausted:
		return null
	if not _visible_exhausted:
		var visible_coordinate = _visible_iterator.next_coordinate()
		if visible_coordinate != null:
			return visible_coordinate
		_visible_exhausted = true
	while true:
		var expanded_coordinate = _expanded_iterator.next_coordinate()
		if expanded_coordinate == null:
			_exhausted = true
			return null
		if not _inside_visible(expanded_coordinate):
			return expanded_coordinate


func is_exhausted() -> bool:
	return _exhausted


func _inside_visible(coordinate: SectorCoordinate) -> bool:
	return (
		absi(coordinate.x - _center.x) <= _visible_radii.x
		and absi(coordinate.y - _center.y) <= _visible_radii.y
	)
```

- [ ] **Step 4: Run iterator suites and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_prioritized_sector_iterator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/streaming/test_sector_ring_iterator.gd'
```

Expected: both print `TESTS PASSED` and exit 0.

- [ ] **Step 5: Commit the iterator**

```powershell
git add -- scripts/application/streaming/prioritized_sector_iterator.gd tests/application/streaming/test_prioritized_sector_iterator.gd tests/test_runner.gd
git commit -m "feat: enumerate visible sectors before preload"
```

---

### Task 3: Schedule controller generation visible-first

**Files:**
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Test: `tests/adapters/godot_view/test_sector_streaming.gd`

**Interfaces:**
- Consumes: `projection.visible_radii(...)`, `projection.load_radii(...)`, and `PrioritizedSectorIterator`.
- Produces: public `visible_radii: Vector2i`; existing controller API, pending cap, and stats signal stay unchanged.

- [ ] **Step 1: Write the failing controller regression**

Add this test double after `CountingGenerator`:

```gdscript
class OrderedGenerator extends RefCounted:
	var coordinates := []
	var delegate = Generator.new(FakeRepository.new())


	func generate_sector(coordinate):
		coordinates.append(coordinate.offset(0, 0))
		return delegate.generate_sector(coordinate)
```

Call `_test_visible_sectors_materialize_before_external_preload()` from `run()`
and add:

```gdscript
func _test_visible_sectors_materialize_before_external_preload() -> void:
	var generator = OrderedGenerator.new()
	var view = View.new()
	var controller = Controller.new()
	controller.configure(
		generator,
		view,
		PositionType.new(Coordinate.new(), Vector2.ZERO)
	)
	controller.update_view(300.0, Vector2(50.0, 100.0))
	controller.process_pending(46)

	assert_equal(controller.visible_radii, Vector2i(2, 4), "visible target")
	assert_equal(controller.load_radii, Vector2i(7, 14), "expanded target")
	assert_equal(generator.coordinates.size(), 46, "reference requests are generated")
	for index in 45:
		var coordinate = generator.coordinates[index]
		assert_true(
			absi(coordinate.x) <= 2 and absi(coordinate.y) <= 4,
			"request %d remains inside visible coverage" % index
		)
	var first_external = generator.coordinates[45]
	assert_true(
		absi(first_external.x) > 2 or absi(first_external.y) > 4,
		"first external request follows all visible sectors"
	)
	assert_true(
		controller.pending.size() <= Settings.stream_max_pending_sectors,
		"visible priority preserves the pending cap"
	)
	controller.free()
	view.free()
```

- [ ] **Step 2: Run the controller suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: FAIL because `SectorStreamController.visible_radii` does not exist and the old iterator interleaves external coordinates.

- [ ] **Step 3: Integrate the prioritized iterator**

In the controller:

```gdscript
const PrioritizedSectorIterator = preload(
	"res://scripts/application/streaming/prioritized_sector_iterator.gd"
)

var visible_radii: Vector2i
```

Initialize `visible_radii = settings.stream_initial_load_radii`. In `update_view`, calculate both next radii and treat a change in either as `coverage_changed`:

```gdscript
	var next_visible := projection.visible_radii(
		orthographic_size,
		viewport_size.x / viewport_size.y
	)
	var next_load := projection.load_radii(
		orthographic_size,
		viewport_size.x / viewport_size.y
	)
	var coverage_changed := next_visible != visible_radii or next_load != load_radii
	if coverage_changed:
		visible_radii = next_visible
		load_radii = next_load
		unload_radii = projection.unload_radii(load_radii)
```

Replace iterator construction with:

```gdscript
		_iterator = PrioritizedSectorIterator.new(center, visible_radii, load_radii)
```

- [ ] **Step 4: Run focused and full verification**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

Expected: every command exits 0; test commands print `TESTS PASSED`, catalog validation reports success, and smoke exits without script errors.

- [ ] **Step 5: Commit and push the completed implementation**

```powershell
git add -- scripts/adapters/godot_view/sector_stream_controller.gd tests/adapters/godot_view/test_sector_streaming.gd
git commit -m "feat: prioritize visible sector rendering"
git push origin codex/star-map-engine
```

## Completion Checklist

- [ ] No external sector appears before all 45 visible sectors at the rectangular reference view.
- [ ] Final expanded coverage remains 15 by 29 at the rectangular reference view.
- [ ] Pending queue remains bounded at 256 and frame generation remains 2.
- [ ] No unrelated Godot editor artifacts are staged.
- [ ] Focused tests, full suite, catalog validation, and headless smoke pass.
