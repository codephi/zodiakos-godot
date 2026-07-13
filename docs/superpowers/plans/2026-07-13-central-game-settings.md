# Central Game Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every current tunable production value into one Inspector-editable `res://config/game_settings.tres` and make it the required home for future tuning values.

**Architecture:** A typed `GameSettings` resource defines categories and validation without production defaults; the `.tres` stores every production value explicitly. Godot adapters and visuals load the shared resource, while deterministic domain objects accept configuration through constructors so simulation remains testable independently of scenes.

**Tech Stack:** Godot 4.7, GDScript, `.tres` resources, native Windows PowerShell, existing custom test runner.

## Global Constraints

- `res://config/game_settings.tres` is the only source of production tuning values.
- `res://scripts/config/game_settings.gd` contains types and validation, not production defaults.
- Existing seed, generator output, zoom behavior, streaming coverage, geometry, colors, and lighting remain unchanged.
- Invalid settings return field-specific validation errors and are rejected before universe creation.
- Domain rules receive the configuration they need through constructors.
- All new tunable values must be added to `game_settings.tres`; structural invariants remain in code.
- Native Windows PowerShell and Godot 4.7 are used for all checks.
- Handwritten files remain below 1,000 lines.
- The unrelated local `project.godot` modification remains unstaged.

---

### Task 1: Typed central resource and validation

**Files:**
- Create: `scripts/config/game_settings.gd`
- Create: `config/game_settings.tres`
- Create: `tests/config/test_game_settings.gd`
- Modify: `tests/test_runner.gd`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: `GameSettings.validation_errors() -> PackedStringArray`.
- Produces: `GameSettings.is_valid() -> bool`.
- Produces: `preload("res://config/game_settings.tres")` as the shared production resource.

- [ ] **Step 1: Register a failing resource contract test**

Create `tests/config/test_game_settings.gd` and register it in `TEST_SCRIPTS`. The suite must load the central resource, assert the current camera, streaming, universe, palette, geometry, material, environment, and demo values, and exercise invalid copies:

```gdscript
extends "res://tests/test_case.gd"

const Settings = preload("res://config/game_settings.tres")


func run() -> void:
	assert_true(Settings is GameSettings, "central settings use the typed resource")
	assert_equal(Settings.camera_min_zoom, 20.0, "camera minimum zoom")
	assert_equal(Settings.camera_max_zoom, 300.0, "camera maximum zoom")
	assert_equal(Settings.camera_initial_zoom, 50.0, "camera initial zoom")
	assert_equal(Settings.camera_zoom_factor, 0.88, "camera zoom factor")
	assert_equal(Settings.stream_sectors_per_frame, 2, "stream frame budget")
	assert_equal(Settings.universe_global_seed, 0x5A4F4449414B4F53, "global seed")
	assert_equal(Settings.universe_sector_size, 40.0, "sector size")
	assert_equal(Settings.universe_visual_type_weights, [35, 25, 20, 15, 5], "visual weights")
	assert_equal(Settings.star_styles[&"yellow"].scale, 1.0, "yellow star scale")
	assert_equal(Settings.ship_prism_size, Vector3(0.8, 0.3, 1.4), "ship base mesh")
	assert_equal(Settings.material_emission_multiplier, 1.8, "material emission")
	assert_true(Settings.is_valid(), "production settings are valid")
	assert_equal(Settings.validation_errors(), PackedStringArray(), "valid settings have no errors")

	var invalid = Settings.duplicate(true)
	invalid.camera_min_zoom = invalid.camera_max_zoom + 1.0
	invalid.camera_zoom_factor = 1.0
	invalid.stream_min_aspect_ratio = 0.0
	invalid.universe_min_clusters = invalid.universe_max_clusters + 1
	invalid.universe_visual_types = []
	invalid.universe_visual_type_weights = []
	var errors: PackedStringArray = invalid.validation_errors()
	assert_true(errors.size() >= 5, "validation reports every invalid relationship")
	assert_true(not invalid.is_valid(), "invalid settings are rejected")
```

- [ ] **Step 2: Run the focused suite and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: FAIL because `res://config/game_settings.tres` does not exist.

- [ ] **Step 3: Define the typed schema without production defaults**

Create `GameSettings extends Resource` with exported categories and these exact fields:

```gdscript
@export_category("Map Camera")
@export var camera_min_zoom: float
@export var camera_max_zoom: float
@export var camera_initial_zoom: float
@export var camera_zoom_factor: float
@export var camera_height: float
@export var camera_drag_threshold_pixels: float

@export_category("Map Streaming")
@export var stream_initial_load_radii: Vector2i
@export var stream_load_margin: int
@export var stream_unload_margin: int
@export var stream_min_aspect_ratio: float
@export var stream_max_aspect_ratio: float
@export var stream_sectors_per_frame: int

@export_category("Procedural Universe")
@export var universe_global_seed: int
@export var universe_generator_version: int
@export var universe_sector_size: float
@export var universe_min_clusters: int
@export var universe_max_clusters: int
@export var universe_min_cluster_stars: int
@export var universe_max_cluster_stars: int
@export var universe_min_cluster_radius: float
@export var universe_max_cluster_radius: float
@export var universe_max_isolated_stars: int
@export var universe_minimum_star_distance: float
@export var universe_max_stars_per_sector: int
@export var universe_visual_types: Array[StringName]
@export var universe_visual_type_weights: Array[int]

@export_category("Visual Palette")
@export var neutral_owner_color: Color
@export var ship_styles: Dictionary
@export var star_styles: Dictionary
@export var planet_styles: Dictionary

@export_category("Geometric Visuals")
@export var star_sphere_radial_segments: int
@export var star_sphere_rings: int
@export var planet_sphere_radial_segments: int
@export var planet_sphere_rings: int
@export var planet_minimum_scale: float
@export var ring_thickness: float
@export var ring_rings: int
@export var ring_segments: int
@export var star_selected_ring_radius: float
@export var star_owner_ring_radius: float
@export var ship_owner_ring_radius: float
@export var ship_owner_ring_height: float
@export var ship_prism_size: Vector3
@export var zodiac_area_opacity: float
@export var material_emission_multiplier: float

@export_category("Map Environment")
@export var map_background_color: Color
@export var map_ambient_light_color: Color
@export var map_ambient_light_energy: float

@export_category("Geometric Demo")
@export var demo_owner_color: Color
@export var demo_camera_position: Vector3
@export var demo_camera_rotation_degrees: Vector3
@export var demo_camera_fov: float
@export var demo_light_rotation_degrees: Vector3
@export var demo_light_energy: float
@export var demo_background_color: Color
@export var demo_ambient_light_color: Color
@export var demo_ambient_light_energy: float
@export var demo_territory_line_thickness: float
@export var demo_route_line_thickness: float
@export var demo_route_color: Color
@export var demo_star_types: Array[StringName]
@export var demo_ship_classes: Array[StringName]
@export var demo_planet_types: Array[StringName]
```

Implement validation helpers that append exact field names for invalid zoom ordering, zoom factor, positive dimensions, range ordering, nonnegative streaming values, aspect ordering, nonempty matching visual arrays, positive weights, required fallback palette keys, and `max_stars_per_sector >= max_clusters * max_cluster_stars + max_isolated_stars`.

- [ ] **Step 4: Create the single production `.tres`**

Populate every exported field explicitly with the values documented in the spec and the existing scripts. Preserve palette dictionaries, mesh subdivisions, environment colors, camera values, and the existing visual distribution weights `[35, 25, 20, 15, 5]`.

- [ ] **Step 5: Add the future-settings repository rule**

Append to `AGENTS.md`:

```markdown
## Central Game Settings

- Put every new tunable gameplay, map, camera, generation, presentation, lighting, or demo value in `config/game_settings.tres`.
- Declare its typed Inspector field and validation in `scripts/config/game_settings.gd`.
- Do not duplicate production tuning values as local constants or defaults; keep only structural and mathematical invariants in code.
```

- [ ] **Step 6: Run the focused suite and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
```

Expected: `TESTS PASSED` and `GODOT TEST WRAPPER PASSED` with empty stderr.

- [ ] **Step 7: Commit and push Task 1**

```powershell
git add AGENTS.md config/game_settings.tres scripts/config/game_settings.gd tests/config/test_game_settings.gd tests/test_runner.gd
git commit -m "feat: add central game settings resource"
git push origin codex/star-map-engine
```

---

### Task 2: Migrate deterministic universe configuration

**Files:**
- Modify: `scripts/domain/universe/universe_generator.gd`
- Modify: `scripts/domain/universe/universe_position.gd`
- Modify: `scripts/domain/universe/star_definition.gd`
- Modify: `scripts/domain/universe/universe_sector.gd`
- Modify: `scripts/adapters/godot_view/star_field_view.gd`
- Delete: `scripts/domain/universe/universe_generator_config.gd`
- Delete: `scripts/domain/universe/universe_generator_config.gd.uid`
- Delete: `scripts/domain/universe/universe_scale.gd`
- Delete: `scripts/domain/universe/universe_scale.gd.uid`
- Modify: `tests/domain/universe/test_generation_foundations.gd`
- Modify: `tests/domain/universe/test_universe_coordinates.gd`
- Modify: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`

**Interfaces:**
- Produces: `UniverseGenerator.new(seed = null, configuration = Settings)`.
- Produces: `UniversePosition.new(initial_sector = null, initial_local = Vector2.ZERO, sector_size = Settings.universe_sector_size)`.
- Produces: version arguments on `StarDefinition` and `UniverseSector`, defaulting to central settings.

- [ ] **Step 1: Write failing injection and equivalence tests**

Replace legacy config assertions with central settings assertions. Add a duplicated configuration with `universe_max_isolated_stars = 0` and prove an injected generator obeys it. Capture the existing deterministic signature for sector `(-2, 3)` before production changes and assert the migrated default generator returns exactly that signature.

- [ ] **Step 2: Run domain suites and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_generation_foundations.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
```

Expected: FAIL because constructors do not accept the central resource and legacy constants still exist.

- [ ] **Step 3: Inject settings through universe objects**

Store `configuration` on `UniverseGenerator`; derive the default seed from it when `seed == null`; replace every `Config.*` read with the corresponding `configuration.universe_*` field. Implement weighted visual selection with the configured types and weights while preserving the current `0..99` roll for the production total of `100`.

Store `sector_size` on `UniversePosition`, preserve it in `moved`, and use it in normalization and relative coordinates. Pass the configured generator version into generated stars and sectors. Make `StarFieldView` read `Settings.universe_sector_size` for visual placement.

- [ ] **Step 4: Remove legacy configuration scripts and update consumers**

Delete `universe_generator_config.gd`, `universe_scale.gd`, and their tracked UIDs. Replace all remaining imports and test references with the central resource or injected settings.

- [ ] **Step 5: Run domain and streaming suites and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_coordinates.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_generation_foundations.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_universe_generator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
```

Expected: every suite passes and the default deterministic signatures remain unchanged.

- [ ] **Step 6: Commit and push Task 2**

```powershell
git add scripts/domain/universe scripts/adapters/godot_view/star_field_view.gd tests/domain/universe tests/adapters/godot_view/test_sector_streaming.gd
git commit -m "refactor: source universe tuning from game settings"
git push origin codex/star-map-engine
```

---

### Task 3: Migrate camera and streaming configuration

**Files:**
- Modify: `scripts/adapters/godot_view/map_camera_controller.gd`
- Modify: `scripts/application/projections/visible_sector_projection.gd`
- Modify: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/demo/infinite_star_map_demo.gd`
- Modify: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Modify: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/demo/test_infinite_star_map_demo.gd`

**Interfaces:**
- Produces: `MapCameraController.new(configuration = Settings)`.
- Produces: `VisibleSectorProjection.new(configuration = Settings)`.
- Produces: `SectorStreamController.new(configuration = Settings)`.
- Preserves: cursor-anchored scroll and all public camera/stream methods.

- [ ] **Step 1: Write failing custom camera and projection tests**

Duplicate central settings and set camera zoom values to `10.0`, `25.0`, `40.0` with factor `0.5`; assert the injected camera initializes at `25.0` and clamps at `10.0` and `40.0`. Set projection load margin to `2`, sector size to `20.0`, and aspect bounds to `1.0`; assert `load_radii(40.0, 4.0) == Vector2i(3, 3)`. Set stream frame budget to `1`; assert `process_pending()` materializes one sector.

- [ ] **Step 2: Run focused suites and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
```

Expected: FAIL because these objects do not yet accept configuration.

- [ ] **Step 3: Replace local camera and streaming constants**

Store the injected settings on all three objects. Initialize camera size and height from settings; use the configured drag threshold, zoom factor, and limits. Calculate projection radii from configured sector size, margins, and aspect bounds. Initialize stream radii from `stream_initial_load_radii`, derive unload radii through projection, and make the no-argument `process_pending()` use `stream_sectors_per_frame` while explicit limits remain supported.

Update the infinite demo to load one central settings resource, construct camera, generator, and stream with it, configure environment colors and energy from it, and show `universe_global_seed` in the HUD.

- [ ] **Step 4: Run focused suites and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_map_camera_controller.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/projections/test_visible_sector_projection.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/godot_view/test_sector_streaming.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_infinite_star_map_demo.gd'
```

Expected: all suites pass with the current `20/50/300` zoom and existing coverage counts.

- [ ] **Step 5: Commit and push Task 3**

```powershell
git add scripts/adapters/godot_view/map_camera_controller.gd scripts/application/projections/visible_sector_projection.gd scripts/adapters/godot_view/sector_stream_controller.gd scripts/demo/infinite_star_map_demo.gd tests/adapters/godot_view tests/application/projections tests/demo/test_infinite_star_map_demo.gd
git commit -m "refactor: source map tuning from game settings"
git push origin codex/star-map-engine
```

---

### Task 4: Migrate visual, material, lighting, and demo configuration

**Files:**
- Modify: `scripts/visuals/visual_palette.gd`
- Modify: `scripts/visuals/material_factory.gd`
- Modify: `scripts/visuals/star_visual.gd`
- Modify: `scripts/visuals/planet_visual.gd`
- Modify: `scripts/visuals/ship_visual.gd`
- Modify: `scripts/visuals/ring_visual.gd`
- Modify: `scripts/visuals/zodiac_area_visual.gd`
- Modify: `scripts/demo/geometric_visual_demo.gd`
- Modify: `tests/visuals/test_visual_palette.gd`
- Modify: `tests/visuals/test_geometric_components.gd`
- Modify: `tests/demo/test_geometric_visual_demo.gd`

**Interfaces:**
- Preserves: public `configure` methods for all geometric components.
- Produces: palette lookup and geometry from the central resource without local production tuning constants.

- [ ] **Step 1: Write failing central visual-value tests**

Extend visual tests to assert sphere subdivisions, ring subdivisions and thickness, ship prism size, zodiac opacity, material emission, and demo camera/light/environment values match `game_settings.tres`. Keep existing fallback and geometric-base assertions.

- [ ] **Step 2: Run visual suites and verify RED**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/visuals/test_visual_palette.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/visuals/test_geometric_components.gd'
```

Expected: FAIL because visual scripts still own the tuning literals.

- [ ] **Step 3: Replace visual constants and literals**

Make `VisualPalette` read `ship_styles`, `star_styles`, `planet_styles`, and `neutral_owner_color` from the central resource. Make `VisualMaterialFactory` use `material_emission_multiplier`. Make star, planet, ship, ring, and zodiac visuals use the corresponding central geometry fields while retaining only mathematical guards such as zero-length epsilon in code.

Update `geometric_visual_demo.gd` to use the configured owner color, demo type lists, camera transform/FOV, directional light, environment, line thicknesses, and route color. Keep sample positions as scene content.

- [ ] **Step 4: Run visual and demo suites and verify GREEN**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/visuals/test_visual_palette.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/visuals/test_geometric_components.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/demo/test_geometric_visual_demo.gd'
```

Expected: all visual and demo suites pass with unchanged colors, scales, meshes, and lighting.

- [ ] **Step 5: Run full verification and configuration audit**

```powershell
./tools/run_godot_tests.ps1
& "$env:LOCALAPPDATA\Programs\Godot\4.7\godot_console.exe" --headless --path . --editor --quit
rg -n "MINIMUM_SIZE|MAXIMUM_SIZE|ZOOM_FACTOR|GLOBAL_SEED|MAX_CLUSTERS|MIN_CLUSTER_RADIUS|NEUTRAL_OWNER|emission_energy_multiplier = 1.8|ambient_light_energy = 1.0" scripts --glob '*.gd'
git diff --check
```

Expected: tests and smoke pass, the audit returns no duplicated production tuning declarations, and no handwritten file exceeds 1,000 lines.

- [ ] **Step 6: Commit and push Task 4**

```powershell
git add scripts/visuals scripts/demo/geometric_visual_demo.gd tests/visuals tests/demo/test_geometric_visual_demo.gd
git commit -m "refactor: source visual tuning from game settings"
git push origin codex/star-map-engine
```
