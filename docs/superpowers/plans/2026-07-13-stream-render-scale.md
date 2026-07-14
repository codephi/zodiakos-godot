# Stream Render Scale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable linear multiplier that expands procedural streaming width and height beyond the visible viewport while retaining one fixed safety-sector ring.

**Architecture:** `GameSettings` owns and validates the multiplier. The pure `VisibleSectorProjection` applies it before sector rounding; controller and demo continue consuming only computed radii and remain unaware of the formula.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, native Windows PowerShell, existing custom Godot test runner.

## Global Constraints

- Develop and validate on native Windows; do not use WSL.
- Keep every handwritten file at or below 1,000 lines.
- Use TDD and observe focused failures before production changes.
- Set `stream_render_scale = 10.0`, `stream_load_margin = 1`, and `stream_unload_margin = 1` in production.
- Require `stream_render_scale >= 1.0`.
- Apply scale to both visible dimensions before sector rounding; apply fixed margin afterward.
- Keep the setting out of `UniverseIdentity` and canonical system generation.
- Do not eagerly materialize production-scale coverage in integration tests.
- Preserve center-first ordering, invalid-viewport behavior and unload hysteresis.
- Commit and push after every completed task.

---

### Task 1: Complete stream render scale delivery

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify: `config/game_settings.tres`
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Modify: `tests/config/test_game_settings.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `docs/superpowers/specs/2026-07-13-central-game-settings-design.md`
- Modify: `docs/superpowers/specs/2026-07-13-extended-map-zoom-design.md`

**Interfaces:**
- `GameSettings.stream_render_scale: float` is editable in the `Map Streaming` Inspector category.
- `VisibleSectorProjection.load_radii(orthographic_size: float, aspect_ratio: float) -> Vector2i` retains its signature.
- Projection multiplies the nonnegative half-height by scale, derives width using the clamped aspect ratio, rounds each axis up to whole sectors, then adds `stream_load_margin`.

- [ ] **Step 1: Write failing configuration tests**

In `tests/config/test_game_settings.gd`, replace the temporary margin assertion
with:

```gdscript
assert_equal(Settings.stream_render_scale, 10.0, "stream render scale")
assert_equal(Settings.stream_load_margin, 1, "stream keeps one safety ring")
```

Add these validation cases alongside the other `_assert_validation_error` calls:

```gdscript
_assert_validation_error(
	&"stream_render_scale",
	0.99,
	"stream_render_scale must be at least 1"
)

var minimum_scale = Settings.duplicate(true)
minimum_scale.stream_render_scale = 1.0
assert_true(minimum_scale.is_valid(), "render scale one remains valid")
```

- [ ] **Step 2: Write failing projection and identity tests**

Replace the production projection expectations in
`tests/application/projections/test_visible_sector_projection.gd` with:

```gdscript
assert_equal(
	projection.load_radii(300.0, 16.0 / 9.0),
	Vector2i(68, 39),
	"render scale expands both 16:9 dimensions before rounding"
)
assert_equal(
	projection.load_radii(300.0, 9.0 / 16.0),
	Vector2i(23, 39),
	"portrait scale follows visible width"
)
assert_equal(
	projection.load_radii(300.0, 32.0 / 9.0),
	Vector2i(135, 39),
	"ultrawide scale follows visible width"
)
assert_equal(
	projection.load_radii(300.0, 1920.0),
	Vector2i(151, 39),
	"degenerate wide viewport clamps before scaling"
)
assert_equal(
	projection.load_radii(300.0, 1.0 / 1920.0),
	Vector2i(11, 39),
	"degenerate tall viewport retains scaled horizontal coverage"
)
assert_equal(
	projection.load_radii(500.0, 1.0),
	Vector2i(64, 64),
	"five-hundred square expands to at least five thousand square"
)
```

In the injected-settings block, add:

```gdscript
custom.stream_render_scale = 1.0
```

Keep its expected load radius `(3, 3)` to prove scale one plus the injected
two-sector margin.

In `tests/domain/universe/test_universe_generator.gd`, register and add:

```gdscript
func _test_stream_render_scale_does_not_version_universe() -> void:
	var metadata = Metadata.new(1, 2, 3)
	var baseline = Identity.new(101, 7, metadata, Settings).value
	var changed = Settings.duplicate(true)
	changed.stream_render_scale = 2.0
	assert_equal(
		Identity.new(101, 7, metadata, changed).value,
		baseline,
		"presentation render scale stays outside universe identity"
	)
```

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: settings/projection fail because the field and formula are absent. The
identity test may fail to parse until the typed field exists; after the field is
introduced it must pass without changes to `UniverseIdentity`.

- [ ] **Step 4: Add and validate the central setting**

In `scripts/config/game_settings.gd`, add after
`stream_initial_load_radii`:

```gdscript
@export var stream_render_scale: float
```

In `_validate_streaming`, add before margin validation:

```gdscript
if stream_render_scale < 1.0:
	errors.append("stream_render_scale must be at least 1")
```

In `config/game_settings.tres`, set:

```text
stream_render_scale = 10.0
stream_load_margin = 1
stream_unload_margin = 1
```

- [ ] **Step 5: Apply scale in the projection**

Replace the first line of `load_radii` with:

```gdscript
var scaled_half_height := (
	maxf(orthographic_size, 0.0)
	* 0.5
	* settings.stream_render_scale
)
```

Use `scaled_half_height` for both returned height and width:

```gdscript
var scaled_half_width := scaled_half_height * safe_aspect_ratio
return Vector2i(
	ceili(scaled_half_width / settings.universe_sector_size)
		+ settings.stream_load_margin,
	ceili(scaled_half_height / settings.universe_sector_size)
		+ settings.stream_load_margin
)
```

Do not modify `load_order`, `unload_radii`, controller code or universe identity.

- [ ] **Step 6: Align existing design documents**

In `docs/superpowers/specs/2026-07-13-central-game-settings-design.md`, replace
the temporary ten-sector margin with:

```markdown
- escala linear da área pré-carregada: `10.0`;
- margem fixa de carregamento: `1` setor;
```

In `docs/superpowers/specs/2026-07-13-extended-map-zoom-design.md`, replace the
sentence about a ten-sector margin with:

```markdown
O cálculo multiplica largura e altura visíveis pela escala configurada `10.0`
antes do arredondamento por setores. Uma margem fixa de um setor é aplicada
depois do arredondamento, e a descarga mantém sua margem adicional de histerese.
```

- [ ] **Step 7: Keep controller integration tests bounded**

Add this helper near the bottom of
`tests/adapters/godot_view/test_sector_streaming.gd`:

```gdscript
func _unscaled_stream_settings():
	var custom = Settings.duplicate(true)
	custom.stream_render_scale = 1.0
	custom.stream_load_margin = 1
	return custom
```

In these three tests, construct the controller with
`Controller.new(_unscaled_stream_settings())`:

- `_test_zoom_coverage_reuses_active_sectors_and_unloads_with_hysteresis`;
- `_test_non_positive_viewport_width_is_ignored`;
- `_test_extreme_positive_viewport_is_safely_bounded`.

Restore their scale-one expectations:

```gdscript
view.active_sector_count() == 187
view.active_sector_count() <= 63
controller.load_radii == Vector2i(16, 5)
controller.pending.size() == 363
```

Keep `process_pending(controller.pending.size())`; it drains the complete
injected queue without embedding a batch-size magic number.

- [ ] **Step 8: Update production demo routing expectations**

In `tests/demo/test_infinite_star_map_demo.gd`, use:

```gdscript
Vector2i(68, 39)  # 300 high, 16:9
Vector2i(23, 39)  # 300 high, 9:16
Vector2i(135, 39) # 300 high, 32:9
```

These tests inspect `stream.load_radii` only and must not call `process_pending`
for production scale.

- [ ] **Step 9: Run focused, full, catalog and smoke verification**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
./tools/run_godot_tests.ps1
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --quit-after 20
git diff --check
```

Expected: focused/full suites print `TESTS PASSED`, catalog prints
`CATALOG VALID`, smoke exits `0` and diff check is clean.

- [ ] **Step 10: Commit and push the atomic implementation**

```powershell
git add scripts/config/game_settings.gd config/game_settings.tres scripts/application/projections/visible_sector_projection.gd tests/config/test_game_settings.gd tests/application/projections/test_visible_sector_projection.gd tests/domain/universe/test_universe_generator.gd tests/adapters/godot_view/test_sector_streaming.gd tests/demo/test_infinite_star_map_demo.gd docs/superpowers/specs/2026-07-13-central-game-settings-design.md docs/superpowers/specs/2026-07-13-extended-map-zoom-design.md
git commit -m "feat: scale procedural streaming beyond viewport"
git push
```
