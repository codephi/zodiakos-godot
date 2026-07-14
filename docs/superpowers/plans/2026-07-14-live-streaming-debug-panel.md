# Live Streaming Debug Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a temporary F3 debug panel that can make streaming preload use a configurable minimum zoom, update budgets live, display its effect, and restore session defaults without writing files.

**Architecture:** The demo duplicates the central `GameSettings` resource once per run and injects that shared runtime copy into camera, view, generator, and stream controller. `VisibleSectorProjection` separates visual zoom from effective preload zoom, while a reusable `StreamingDebugPanel` only emits validated UI proposals and renders snapshots; the demo remains the composition root that applies changes and refreshes streaming.

**Tech Stack:** Godot 4.7 Compatibility renderer, typed GDScript, native Godot `Control` widgets, the existing synchronous test runner, PowerShell on Windows.

## Global Constraints

- Run only on Windows with PowerShell; do not use WSL.
- Keep every source file below 1000 lines and preserve SOLID/component reuse boundaries.
- Keep configuration declarations centralized in `GameSettings` and `config/game_settings.tres`.
- Runtime panel changes are session-only and must never call persistence APIs.
- Fixed preload uses `max(camera_zoom, stream_fixed_preload_zoom)` and never reduces visible coverage.
- `stream_sectors_per_frame = 0` remains valid and pauses materialization.
- Preserve unrelated Inspector edits in `config/game_settings.tres`, scene UID serialization, generated `.gd.uid` files, and the temporary SQLite DLL.
- Write tests before production code and commit/push each completed task.

---

### Task 1: Fixed Preload Zoom Contract

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`

**Interfaces:**
- Consumes: `GameSettings.validation_errors()` and `VisibleSectorProjection._coverage_radii(...)`.
- Produces: `stream_use_fixed_preload_zoom: bool`, `stream_fixed_preload_zoom: float`, and `effective_preload_zoom(camera_zoom: float) -> float`.

- [ ] **Step 1: Write failing settings and identity tests**

Add production assertions and invalid-value cases:

```gdscript
assert_true(not Settings.stream_use_fixed_preload_zoom, "fixed preload is opt-in")
assert_equal(Settings.stream_fixed_preload_zoom, 1000.0, "fixed preload reference zoom")
_assert_validation_error(
	&"stream_fixed_preload_zoom",
	-0.01,
	"stream_fixed_preload_zoom must be nonnegative"
)
_assert_validation_error(
	&"stream_fixed_preload_zoom",
	NAN,
	"stream_fixed_preload_zoom must be nonnegative"
)
_assert_validation_error(
	&"stream_fixed_preload_zoom",
	INF,
	"stream_fixed_preload_zoom must be nonnegative"
)
```

Add an identity assertion that changing both new presentation fields does not
change `UniverseIdentity.value`.

- [ ] **Step 2: Write failing projection tests**

Use a duplicated settings object and assert all three branches:

```gdscript
var fixed = Settings.duplicate(true)
fixed.stream_use_fixed_preload_zoom = true
fixed.stream_fixed_preload_zoom = 1000.0
var fixed_projection = ProjectionScript.new(fixed)
assert_equal(fixed_projection.effective_preload_zoom(30.0), 1000.0, "fixed zoom is a floor")
assert_equal(fixed_projection.visible_radii(30.0, 16.0 / 9.0), Vector2i(1, 1), "visible uses camera zoom")
assert_equal(fixed_projection.load_radii(30.0, 16.0 / 9.0), Vector2i(67, 38), "preload uses fixed zoom")
assert_equal(fixed_projection.effective_preload_zoom(1200.0), 1200.0, "camera above floor wins")
fixed.stream_use_fixed_preload_zoom = false
assert_equal(fixed_projection.effective_preload_zoom(30.0), 30.0, "disabled mode follows camera")
```

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: failures for missing fields and `effective_preload_zoom`.

- [ ] **Step 4: Implement the settings and projection**

Add under `Map Streaming`:

```gdscript
@export var stream_use_fixed_preload_zoom: bool
@export var stream_fixed_preload_zoom: float
```

Validate finiteness and range explicitly:

```gdscript
if (
	is_nan(stream_fixed_preload_zoom)
	or is_inf(stream_fixed_preload_zoom)
	or stream_fixed_preload_zoom < 0.0
):
	errors.append("stream_fixed_preload_zoom must be nonnegative")
```

Add to `game_settings.tres` without staging unrelated local edits:

```text
stream_use_fixed_preload_zoom = false
stream_fixed_preload_zoom = 1000.0
```

Implement projection behavior:

```gdscript
func effective_preload_zoom(camera_zoom: float) -> float:
	var safe_camera_zoom := maxf(camera_zoom, 0.0)
	if not settings.stream_use_fixed_preload_zoom:
		return safe_camera_zoom
	return maxf(safe_camera_zoom, settings.stream_fixed_preload_zoom)

func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var visible := visible_radii(orthographic_size, aspect_ratio)
	var expanded := _coverage_radii(
		effective_preload_zoom(orthographic_size),
		aspect_ratio,
		float(settings.stream_viewport_grid_size)
	)
	return Vector2i(maxi(expanded.x, visible.x), maxi(expanded.y, visible.y))
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the three commands from Step 3. Expected: each prints `TESTS PASSED` and
`GODOT TEST WRAPPER PASSED`.

- [ ] **Step 6: Commit and push**

Stage only the intended settings hunks plus the listed scripts/tests:

```powershell
git diff --cached --check
git commit -m "feat: support fixed preload reference zoom"
git push origin codex/star-map-engine
```

---

### Task 2: Live Stream Budget Reconciliation

**Files:**
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`

**Interfaces:**
- Consumes: mutable runtime `GameSettings`, `update_view(...)`, `pending`, and `queued`.
- Produces: `pending_sector_count() -> int`, `target_sector_count() -> int`, and immediate enforcement of `stream_max_pending_sectors` on the next `update_view(...)`.

- [ ] **Step 1: Write failing controller tests**

Add a test that starts with a cap of 32, reduces it to 7 through the shared
settings object, calls `update_view`, and asserts:

```gdscript
custom.stream_max_pending_sectors = 32
controller.update_view(100.0, Vector2(1920.0, 1080.0))
custom.stream_max_pending_sectors = 7
controller.update_view(100.0, Vector2(1920.0, 1080.0))
assert_equal(controller.pending_sector_count(), 7, "runtime cap trims pending immediately")
assert_equal(controller.pending.size(), controller.queued.size(), "trim keeps queue keys synchronized")
assert_equal(controller.target_sector_count(), 135, "target count reflects load radii")
custom.stream_sectors_per_frame = 0
controller.process_pending()
assert_equal(view.active_sector_count(), 0, "zero runtime frame budget pauses materialization")
```

- [ ] **Step 2: Run the controller test and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: missing public count methods or pending remains above seven.

- [ ] **Step 3: Implement bounded reconciliation and metrics accessors**

Before refilling an unchanged schedule, trim from the least immediate end:

```gdscript
func _trim_pending_to_limit() -> void:
	while pending.size() > settings.stream_max_pending_sectors:
		var removed = pending.pop_back()
		queued.erase(removed.key())

func pending_sector_count() -> int:
	return pending.size()

func target_sector_count() -> int:
	return (2 * load_radii.x + 1) * (2 * load_radii.y + 1)
```

Call `_trim_pending_to_limit()` in `update_view` before `_reconcile_stream`.
Coverage changes still clear and rebuild the schedule through the existing
visible-first iterator.

- [ ] **Step 4: Run the controller test and verify GREEN**

Run the command from Step 2. Expected: `TESTS PASSED`.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/adapters/godot_view/sector_stream_controller.gd tests/adapters/godot_view/test_sector_streaming.gd
git diff --cached --check
git commit -m "feat: reconcile live stream budgets"
git push origin codex/star-map-engine
```

---

### Task 3: Reusable F3 Streaming Debug Panel

**Files:**
- Create: `scripts/adapters/godot_view/streaming_debug_panel.gd`
- Create: `tests/adapters/godot_view/test_streaming_debug_panel.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: a runtime `GameSettings` instance and metric snapshots as `Dictionary`.
- Produces: typed `tuning_changed(...)`, `reset_requested`, `configure(settings)`, `update_metrics(snapshot)`, `show_validation_error(message)`, and `flush_pending_changes()`.

- [ ] **Step 1: Register and write the failing panel test**

Register the suite immediately after the sector streaming suite. Test that the
component builds all controls, starts hidden, toggles with a pressed non-echo F3
event, normalizes grid values to odd numbers, emits the five tuning fields,
updates metric text, and emits reset:

```gdscript
var panel = PanelScript.new()
Engine.get_main_loop().root.add_child(panel)
panel.configure(Settings.duplicate(true))
assert_true(not panel.visible, "debug panel starts hidden")
var f3 := InputEventKey.new()
f3.keycode = KEY_F3
f3.pressed = true
panel.handle_toggle_input(f3)
assert_true(panel.visible, "F3 opens debug panel")
panel.grid_spin.value = 4
panel.flush_pending_changes()
assert_equal(panel.grid_spin.value, 5.0, "even grid normalizes upward")
panel.update_metrics({
	"camera_zoom": 30.0,
	"effective_preload_zoom": 1000.0,
	"visible_radii": Vector2i(1, 1),
	"load_radii": Vector2i(67, 38),
	"target_sectors": 10395,
	"active_sectors": 25,
	"pending_sectors": 256,
	"systems": 11,
})
assert_true(panel.metrics_label.text.contains("Target: 10395"), "panel shows target")
```

- [ ] **Step 2: Run the new panel suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_streaming_debug_panel.gd'
```

Expected: preload failure because the panel script does not exist.

- [ ] **Step 3: Implement the panel component**

Build a `PanelContainer` with a `VBoxContainer`, labels, checkbox, four
`SpinBox` controls, reset button, validation label, and a one-shot `Timer`:

```gdscript
class_name StreamingDebugPanel
extends PanelContainer

signal tuning_changed(
	use_fixed_preload_zoom: bool,
	fixed_preload_zoom: float,
	viewport_grid_size: int,
	sectors_per_frame: int,
	max_pending_sectors: int
)
signal reset_requested

const DEBOUNCE_SECONDS := 0.15

func handle_toggle_input(event: InputEventKey) -> bool:
	if event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		return true
	return false

func flush_pending_changes() -> void:
	change_timer.stop()
	var grid := maxi(int(grid_spin.value), 1)
	if grid % 2 == 0:
		grid += 1
	grid_spin.set_value_no_signal(grid)
	tuning_changed.emit(
		fixed_check.button_pressed,
		fixed_zoom_spin.value,
		grid,
		int(sectors_spin.value),
		int(pending_spin.value)
	)
```

Set `mouse_filter = Control.MOUSE_FILTER_STOP`, numeric minima to `0, 1, 0, 1`,
grid step to `2`, and configure the timer to call `flush_pending_changes`.
`_unhandled_key_input` delegates to `handle_toggle_input` and marks the viewport
input handled when it returns true.

- [ ] **Step 4: Run panel tests and verify GREEN**

Run the command from Step 2. Expected: `TESTS PASSED`.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/adapters/godot_view/streaming_debug_panel.gd tests/adapters/godot_view/test_streaming_debug_panel.gd tests/test_runner.gd
git diff --cached --check
git commit -m "feat: add live streaming debug panel"
git push origin codex/star-map-engine
```

---

### Task 4: Demo Runtime Settings and Live Wiring

**Files:**
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Consumes: `StreamingDebugPanel`, the Task 1 runtime settings, Task 2 count accessors, and existing `_refresh_stream_coverage`.
- Produces: `runtime_settings`, `session_default_settings`, `debug_panel`, `_apply_stream_tuning(...)`, `_reset_stream_tuning()`, and live metric refresh.

- [ ] **Step 1: Write failing demo integration tests**

Assert the same duplicated settings object is injected and the source resource
is unchanged:

```gdscript
var original_fixed: bool = Settings.stream_use_fixed_preload_zoom
var demo = Demo.instantiate()
assert_true(demo.runtime_settings != Settings, "demo uses a runtime settings copy")
assert_true(demo.map_camera.settings == demo.runtime_settings, "camera shares runtime settings")
assert_true(demo.stream.settings == demo.runtime_settings, "stream shares runtime settings")
assert_true(demo.sector_view.settings == demo.runtime_settings, "view shares runtime settings")
demo._apply_stream_tuning(true, 1000.0, 3, 0, 7)
demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
assert_equal(demo.stream.load_radii, Vector2i(67, 38), "panel tuning changes coverage")
assert_equal(demo.stream.pending_sector_count(), 7, "panel tuning changes pending cap")
assert_equal(Settings.stream_use_fixed_preload_zoom, original_fixed, "source resource is untouched")
demo._reset_stream_tuning()
assert_equal(
	demo.runtime_settings.stream_use_fixed_preload_zoom,
	demo.session_default_settings.stream_use_fixed_preload_zoom,
	"reset restores session defaults"
)
```

Also assert `DebugHud/StreamingDebugPanel` exists and its metrics contain the
effective preload zoom and target count after tuning.

- [ ] **Step 2: Run the demo suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

Expected: missing runtime settings and debug panel members.

- [ ] **Step 3: Duplicate and inject runtime settings**

Replace direct construction with one shared deep duplicate:

```gdscript
const DefaultSettings = preload("res://config/game_settings.tres")

var runtime_settings
var session_default_settings
var debug_panel

func _init(repository_override = null) -> void:
	runtime_settings = DefaultSettings.duplicate(true)
	session_default_settings = runtime_settings.duplicate(true)
	map_camera = CameraType.new(runtime_settings)
	sector_view = ViewType.new(runtime_settings)
	stream = StreamType.new(runtime_settings)
```

Use `runtime_settings` instead of the preloaded resource throughout demo
composition, environment, universe position, generator, metrics, and HUD seed.

- [ ] **Step 4: Wire panel proposals, reset, validation, and metrics**

Create the panel under `DebugHud`, connect both signals, and apply only a valid
candidate:

```gdscript
func _apply_stream_tuning(
	use_fixed: bool,
	fixed_zoom: float,
	grid_size: int,
	sectors_per_frame: int,
	max_pending: int
) -> void:
	var candidate = runtime_settings.duplicate(true)
	candidate.stream_use_fixed_preload_zoom = use_fixed
	candidate.stream_fixed_preload_zoom = fixed_zoom
	candidate.stream_viewport_grid_size = grid_size
	candidate.stream_sectors_per_frame = sectors_per_frame
	candidate.stream_max_pending_sectors = max_pending
	var errors: PackedStringArray = candidate.validation_errors()
	if not errors.is_empty():
		debug_panel.show_validation_error(errors[0])
		return
	_copy_stream_tuning(candidate, runtime_settings)
	debug_panel.show_validation_error("")
	_refresh_stream_coverage()
	refresh_debug_hud()
```

`_copy_stream_tuning` copies exactly the five panel-controlled fields. Reset
copies those fields from `session_default_settings`, reconfigures the panel,
and refreshes coverage. Compose metrics from camera, projection, controller,
and view, then call `debug_panel.update_metrics(snapshot)` from stats updates,
zoom updates, tuning changes, and reset.

- [ ] **Step 5: Run focused integration tests and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_streaming_debug_panel.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: all three suites print `TESTS PASSED`.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/demo/infinite_star_map_demo.gd tests/demo/test_infinite_star_map_demo.gd
git diff --cached --check
git commit -m "feat: wire temporary stream tuning into demo"
git push origin codex/star-map-engine
```

---

### Task 5: Full Verification

**Files:**
- Verify only; modify implementation files only if a failing check identifies a defect.

**Interfaces:**
- Consumes: all previous task deliverables.
- Produces: a pushed branch with full test, catalog, headless, formatting, and file-size evidence.

- [ ] **Step 1: Run the full project suite**

```powershell
./tools/run_godot_tests.ps1
```

Expected: `TESTS PASSED`, `TASK 3 REVIEW CHECKS PASSED`, and
`GODOT TEST WRAPPER PASSED`.

- [ ] **Step 2: Validate the scientific catalog**

```powershell
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
```

Expected: `CATALOG VALID`, `TESTS PASSED`, and `GODOT TEST WRAPPER PASSED`.

- [ ] **Step 3: Run the Godot smoke test**

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
```

Expected: Godot exits with code `0` and no script errors.

- [ ] **Step 4: Check formatting, stale fields, and file sizes**

```powershell
git diff --check
rg -n "stream_render_scale" . --glob '!docs/**'
$tooLong = Get-ChildItem scripts,tests -Recurse -Filter *.gd |
	Where-Object { (Get-Content -LiteralPath $_.FullName).Count -gt 1000 }
if ($tooLong) { $tooLong.FullName; exit 1 }
```

Expected: no whitespace errors, no old runtime field references, and no paths
over 1000 lines.

- [ ] **Step 5: Confirm source resource was not changed by runtime tests**

```powershell
git status --short
git diff -- config/game_settings.tres scenes/demo/infinite_star_map_demo.tscn
```

Expected: only the already-preserved user/Inspector changes remain unstaged;
tests introduce no new persistent edits.

- [ ] **Step 6: Push the final verified branch**

```powershell
git push origin codex/star-map-engine
$head = git rev-parse HEAD
$remote = (git ls-remote origin refs/heads/codex/star-map-engine).Split("`t")[0]
if ($head -ne $remote) { throw "Remote branch is not synchronized" }
```

Expected: local and remote SHAs are identical.
