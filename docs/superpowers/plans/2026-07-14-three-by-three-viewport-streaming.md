# Three-by-Three Viewport Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace adaptive 10x streaming with a fixed 3-by-3 viewport grid and set the production maximum zoom to 100.

**Architecture:** `GameSettings` exposes an odd viewport-grid size instead of a render scale. `VisibleSectorProjection` applies linear scale 1 to the central viewport and the configured grid size to final coverage, using the real bounded aspect ratio. Existing visible-first lazy scheduling consumes the projected rectangles unchanged.

**Tech Stack:** Godot 4.7, typed GDScript, Compatibility renderer, native Windows PowerShell, custom headless Godot test runner.

## Global Constraints

- Work in `C:\Users\phili\Documents\Zodiakos\.worktrees\star-map-engine` on `codex/star-map-engine`.
- Use native Windows PowerShell; do not use WSL.
- Production values are `camera_max_zoom = 100.0`, `stream_viewport_grid_size = 3`, `stream_min_aspect_ratio = 0.25`, and `stream_max_aspect_ratio = 4.0`.
- Remove `stream_render_scale`; backward compatibility is not required.
- Preserve visible-first ordering, pending cap 256, and processing budget 2.
- Do not change universe identity, seed, generated systems, SQLite, GPU, LOD, or threads.
- Keep every handwritten file below 1,000 lines.
- Preserve unrelated local Inspector edits and generated `.uid`/temporary DLL files.

---

## File Structure

- Modify `scripts/config/game_settings.gd`: replace the render scale field and validation.
- Modify `config/game_settings.tres`: set production grid, aspect, and zoom values.
- Modify `tests/config/test_game_settings.gd`: prove grid defaults and validation.
- Modify `tests/adapters/godot_view/test_map_camera_controller.gd`: prove maximum zoom 100.
- Modify `tests/domain/universe/test_universe_generator.gd`: prove the grid remains outside universe identity.
- Modify `scripts/application/projections/visible_sector_projection.gd`: remove zoom interpolation and apply the fixed grid.
- Modify `tests/application/projections/test_visible_sector_projection.gd`: prove exact 3x3 geometry.
- Modify `tests/adapters/godot_view/test_sector_streaming.gd`: update visible-first and bounded-queue integration expectations.
- Modify `tests/demo/test_infinite_star_map_demo.gd`: prove camera/viewport routing at production values.

---

### Task 1: Migrate central settings to a viewport grid

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Test: `tests/config/test_game_settings.gd`
- Test: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Test: `tests/domain/universe/test_universe_generator.gd`

**Interfaces:**
- Removes: `stream_render_scale: float`.
- Produces: `stream_viewport_grid_size: int`, positive and odd.
- Preserves: `camera_max_zoom`, camera API, universe identity API.

- [ ] **Step 1: Write failing settings and identity tests**

Update production assertions:

```gdscript
assert_equal(Settings.camera_max_zoom, 100.0, "camera maximum zoom")
assert_equal(Settings.stream_viewport_grid_size, 3, "stream viewport grid")
assert_equal(Settings.stream_max_aspect_ratio, 4.0, "stream maximum aspect")
```

Replace render-scale validation cases with:

```gdscript
_assert_validation_error(
	&"stream_viewport_grid_size",
	0,
	"stream_viewport_grid_size must be positive"
)
_assert_validation_error(
	&"stream_viewport_grid_size",
	2,
	"stream_viewport_grid_size must be odd"
)
var one_by_one = Settings.duplicate(true)
one_by_one.stream_viewport_grid_size = 1
assert_true(one_by_one.is_valid(), "one by one grid remains valid")
var five_by_five = Settings.duplicate(true)
five_by_five.stream_viewport_grid_size = 5
assert_true(five_by_five.is_valid(), "five by five grid remains valid")
```

Change the camera literal assertion to:

```gdscript
assert_equal(Settings.camera_max_zoom, 100.0, "map zoom uses production limit")
```

Rename the identity case and implement it as:

```gdscript
func _test_stream_viewport_grid_does_not_version_universe() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var baseline = Identity.new(101, 7, metadata, Settings).value
	var changed = Settings.duplicate(true)
	changed.stream_viewport_grid_size = 5
	assert_equal(
		Identity.new(101, 7, metadata, changed).value,
		baseline,
		"presentation viewport grid stays outside universe identity"
	)
```

- [ ] **Step 2: Run focused suites and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: FAIL because `stream_viewport_grid_size` does not exist.

- [ ] **Step 3: Implement typed configuration and validation**

Replace the export and streaming validation with:

```gdscript
@export var stream_viewport_grid_size: int
```

```gdscript
_require_positive(errors, "stream_viewport_grid_size", stream_viewport_grid_size)
if stream_viewport_grid_size > 0 and stream_viewport_grid_size % 2 == 0:
	errors.append("stream_viewport_grid_size must be odd")
```

In `config/game_settings.tres`, set:

```text
camera_max_zoom = 100.0
stream_viewport_grid_size = 3
stream_max_aspect_ratio = 4.0
```

Remove `stream_render_scale`. Leave the user's currently omitted zero-valued
margin fields unstaged so their pre-existing Inspector change remains local.

- [ ] **Step 4: Run focused settings, camera, and identity suites**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: every command prints `TESTS PASSED` and exits 0.

- [ ] **Step 5: Stage only intended config values and commit**

Stage code/tests normally. Stage an index-only patch for the three intended
resource changes so omitted margin fields remain unstaged:

```powershell
git add -- scripts/config/game_settings.gd tests/config/test_game_settings.gd tests/adapters/godot_view/test_map_camera_controller.gd tests/domain/universe/test_universe_generator.gd
@'
diff --git a/config/game_settings.tres b/config/game_settings.tres
--- a/config/game_settings.tres
+++ b/config/game_settings.tres
@@ -7 +7 @@
-camera_max_zoom = 1000.0
+camera_max_zoom = 100.0
@@ -14 +14 @@
-stream_render_scale = 10.0
+stream_viewport_grid_size = 3
@@ -18 +18 @@
-stream_max_aspect_ratio = 1.0
+stream_max_aspect_ratio = 4.0
'@ | git apply --cached --unidiff-zero -
git commit -m "feat: configure three by three stream grid"
```

---

### Task 2: Project a fixed 3-by-3 viewport rectangle

**Files:**
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Test: `tests/application/projections/test_visible_sector_projection.gd`

**Interfaces:**
- Consumes: `settings.stream_viewport_grid_size` and bounded aspect ratio.
- Produces: existing `visible_radii(...)` and `load_radii(...)` APIs.

- [ ] **Step 1: Replace adaptive projection expectations with grid expectations**

Use these exact assertions with production settings:

```gdscript
assert_equal(projection.load_radii(300.0, 16.0 / 9.0), Vector2i(20, 12), "grid follows real widescreen aspect")
assert_equal(projection.load_radii(300.0, 9.0 / 16.0), Vector2i(7, 12), "grid follows portrait aspect")
assert_equal(projection.load_radii(300.0, 32.0 / 9.0), Vector2i(40, 12), "grid follows supported ultrawide aspect")
assert_equal(projection.load_radii(300.0, 1920.0), Vector2i(45, 12), "degenerate wide viewport is capped")
assert_equal(projection.load_radii(300.0, 1.0 / 1920.0), Vector2i(3, 12), "degenerate tall viewport is capped")
assert_equal(projection.visible_radii(100.0, 16.0 / 9.0), Vector2i(3, 2), "maximum zoom visible rectangle")
assert_equal(projection.load_radii(100.0, 16.0 / 9.0), Vector2i(7, 4), "maximum zoom three by three grid")
```

For the injected grid-1 case, set `custom.stream_viewport_grid_size = 1` and
retain the expected `(3,3)` radii with its configured margin.

- [ ] **Step 2: Run the focused suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
```

Expected: FAIL because projection still reads the removed render scale.

- [ ] **Step 3: Remove interpolation and apply the fixed grid**

Use:

```gdscript
func load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i:
	var visible := visible_radii(orthographic_size, aspect_ratio)
	var expanded := _coverage_radii(
		orthographic_size,
		aspect_ratio,
		float(settings.stream_viewport_grid_size)
	)
	return Vector2i(maxi(expanded.x, visible.x), maxi(expanded.y, visible.y))
```

Delete `_effective_render_scale`; camera limits no longer affect projection.

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run the same focused command. Expected: `TESTS PASSED` and exit 0.

- [ ] **Step 5: Commit projection behavior**

```powershell
git add -- scripts/application/projections/visible_sector_projection.gd tests/application/projections/test_visible_sector_projection.gd
git commit -m "feat: project fixed viewport stream grid"
```

---

### Task 3: Update streaming and demo integration contracts

**Files:**
- Test: `tests/adapters/godot_view/test_sector_streaming.gd`
- Test: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Consumes: unchanged projection and visible-first iterator APIs.
- Produces: verified production target `(7,4)`, 135 sectors at zoom 100.

- [ ] **Step 1: Update streaming assertions**

Use these exact integration values:

```gdscript
assert_equal(controller.load_radii, Vector2i(6, 12), "expanded target")

controller.update_view(1000.0, Vector2(1920.0, 1080.0))
assert_equal(controller.load_radii, Vector2i(67, 38), "large projection target")
assert_equal(controller.pending.size(), 256, "large projection stays bounded")

assert_equal(controller.load_radii, Vector2i(2, 2), "near zoom grid target")
assert_equal(view.active_sector_count(), 25, "near zoom retains five by five sectors")
```

In `_unscaled_stream_settings()` replace the removed scale assignment with:

```gdscript
custom.stream_viewport_grid_size = 1
```

- [ ] **Step 2: Update demo assertions**

Use:

```gdscript
assert_equal(stream.load_radii, Vector2i(20, 12), "demo forwards reference 16:9 coverage")
```

At the maximum zoom use:

```gdscript
demo.get_node("MapCamera").size = Settings.camera_max_zoom
demo._refresh_stream_coverage(Vector2(1920.0, 1080.0))
assert_equal(stream.load_radii, Vector2i(7, 4), "demo routes maximum grid")
assert_equal(stream.pending.size(), 135, "complete maximum grid fits pending queue")
```

For zoom 300 viewport resize use:

```gdscript
assert_equal(stream.load_radii, Vector2i(7, 12), "portrait grid coverage")
assert_equal(stream.load_radii, Vector2i(40, 12), "ultrawide grid coverage")
```

- [ ] **Step 3: Run focused integration suites**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

Expected: both print `TESTS PASSED` and exit 0.

- [ ] **Step 4: Commit integration contracts**

```powershell
git add -- tests/adapters/godot_view/test_sector_streaming.gd tests/demo/test_infinite_star_map_demo.gd
git commit -m "test: verify three by three stream integration"
```

- [ ] **Step 5: Run final verification and push**

```powershell
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
git diff --check
git push origin codex/star-map-engine
```

Expected: full suite and catalog print `TESTS PASSED`, catalog prints
`CATALOG VALID`, smoke exits 0, and only pre-existing Inspector/generated files
remain unstaged.

## Completion Checklist

- [ ] Production maximum zoom is 100.
- [ ] Production grid is 3 by 3 and aspect cap is 4.
- [ ] Widescreen maximum zoom projects visible `(3,2)` and loaded `(7,4)`.
- [ ] Final production coverage is 135 sectors.
- [ ] Visible-first order, queue cap 256, and frame budget 2 remain intact.
- [ ] Universe identity and system signatures are unchanged.
- [ ] Full tests, catalog validation, and headless smoke pass.
