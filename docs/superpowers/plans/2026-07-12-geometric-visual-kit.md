# Geometric Visual Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Godot 4.7 visual kit and demonstration scene for stars, ships, planets, rings, routes, and Zodiakos using only basic geometric meshes.

**Architecture:** A pure-data palette owns the visual mapping and fallbacks. Small Node3D components own one geometric responsibility each and expose `configure` methods. A demo scene composes those components without embedding gameplay rules, while a lightweight headless runner verifies the data and geometry.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, native `SphereMesh`, `PrismMesh`, `TorusMesh`, `BoxMesh`, and `ArrayMesh`.

## Global Constraints

- Work on native Windows with PowerShell, never WSL.
- Use only basic native meshes or a simple flat procedural surface.
- All gameplay objects remain on the XZ logical plane.
- Reuse materials and component scripts; do not add external assets or plugins.
- Keep every handwritten file below 1,000 lines.
- Commit and push after every completed task.

---

### Task 1: Headless tests and visual palette

**Files:**
- Create: `tests/test_case.gd`
- Create: `tests/test_runner.gd`
- Create: `tests/visuals/test_visual_palette.gd`
- Create: `scripts/visuals/visual_palette.gd`

**Interfaces:**
- Produces: `VisualPalette.ship_style(ship_class: StringName) -> Dictionary`
- Produces: `VisualPalette.star_style(star_type: StringName) -> Dictionary`
- Produces: `VisualPalette.planet_style(planet_type: StringName) -> Dictionary`
- Produces: `VisualPalette.normalize_owner_color(color: Color) -> Color`

- [ ] **Step 1: Add the reusable test case and failing palette tests**

```gdscript
# tests/test_case.gd
extends RefCounted

var failures := 0

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        failures += 1
        push_error("%s: expected %s, got %s" % [message, expected, actual])

func assert_true(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
```

```gdscript
# tests/visuals/test_visual_palette.gd
extends "res://tests/test_case.gd"

const VisualPalette = preload("res://scripts/visuals/visual_palette.gd")

func run() -> void:
    assert_equal(VisualPalette.ship_style(&"expedition").scale, 0.7, "expedition scale")
    assert_equal(VisualPalette.ship_style(&"colony").scale, 1.0, "colony scale")
    assert_equal(VisualPalette.ship_style(&"war").scale, 1.3, "war scale")
    assert_equal(VisualPalette.ship_style(&"unknown"), VisualPalette.ship_style(&"expedition"), "ship fallback")
    assert_equal(VisualPalette.star_style(&"unknown"), VisualPalette.star_style(&"yellow"), "star fallback")
    assert_equal(VisualPalette.planet_style(&"unknown"), VisualPalette.planet_style(&"rocky"), "planet fallback")
    assert_equal(VisualPalette.normalize_owner_color(Color(0, 0, 0, 0)), Color(0.5, 0.5, 0.5, 1), "owner fallback")
```

- [ ] **Step 2: Add the runner and prove the palette test fails**

```gdscript
# tests/test_runner.gd
extends SceneTree

const TEST_SCRIPTS := [
    preload("res://tests/visuals/test_visual_palette.gd"),
]

func _initialize() -> void:
    var failures := 0
    for test_script in TEST_SCRIPTS:
        var suite = test_script.new()
        suite.run()
        failures += suite.failures
    if failures == 0:
        print("TESTS PASSED")
    else:
        push_error("%d TESTS FAILED" % failures)
    quit(failures)
```

Run: `godot --headless --path . --script res://tests/test_runner.gd`

Expected: FAIL because `scripts/visuals/visual_palette.gd` does not exist.

- [ ] **Step 3: Implement the minimal immutable palette**

```gdscript
# scripts/visuals/visual_palette.gd
class_name VisualPalette
extends RefCounted

const NEUTRAL_OWNER := Color(0.5, 0.5, 0.5, 1.0)

const SHIPS := {
    &"expedition": {"color": Color("42d9ff"), "scale": 0.7},
    &"colony": {"color": Color("ffb43c"), "scale": 1.0},
    &"war": {"color": Color("ef4b4b"), "scale": 1.3},
}

const STARS := {
    &"blue": {"color": Color("b9ddff"), "scale": 1.3},
    &"white": {"color": Color.WHITE, "scale": 1.1},
    &"yellow": {"color": Color("ffe58a"), "scale": 1.0},
    &"orange": {"color": Color("ff9b45"), "scale": 0.9},
    &"red": {"color": Color("ff6b60"), "scale": 0.8},
}

const PLANETS := {
    &"rocky": {"color": Color("8f8175")},
    &"gas": {"color": Color("a67ad1")},
    &"ice": {"color": Color("8ed8ef")},
    &"volcanic": {"color": Color("db6a32")},
}

static func ship_style(ship_class: StringName) -> Dictionary:
    return SHIPS.get(ship_class, SHIPS[&"expedition"]).duplicate()

static func star_style(star_type: StringName) -> Dictionary:
    return STARS.get(star_type, STARS[&"yellow"]).duplicate()

static func planet_style(planet_type: StringName) -> Dictionary:
    return PLANETS.get(planet_type, PLANETS[&"rocky"]).duplicate()

static func normalize_owner_color(color: Color) -> Color:
    return NEUTRAL_OWNER if color.a <= 0.0 else color
```

- [ ] **Step 4: Run tests, inspect the diff, commit, and push**

Run: `godot --headless --path . --script res://tests/test_runner.gd`

Expected: `TESTS PASSED`, exit code 0.

Commit: `test: add geometric visual palette`

---

### Task 2: Reusable mesh components

**Files:**
- Create: `scripts/visuals/material_factory.gd`
- Create: `scripts/visuals/ring_visual.gd`
- Create: `scripts/visuals/star_visual.gd`
- Create: `scripts/visuals/ship_visual.gd`
- Create: `scripts/visuals/planet_visual.gd`
- Create: `scripts/visuals/connection_segment.gd`
- Create: `scripts/visuals/zodiac_area_visual.gd`
- Create: `scenes/visuals/ring_visual.tscn`
- Create: `scenes/visuals/star_visual.tscn`
- Create: `scenes/visuals/ship_visual.tscn`
- Create: `scenes/visuals/planet_visual.tscn`
- Create: `scenes/visuals/connection_segment.tscn`
- Create: `scenes/visuals/zodiac_area_visual.tscn`
- Create: `tests/visuals/test_geometric_components.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: all `VisualPalette` functions from Task 1.
- Produces: `configure` methods on every visual component.
- Produces: `ConnectionSegment.configure_between(origin: Vector3, destination: Vector3, thickness: float, color: Color)`.
- Produces: `ZodiacAreaVisual.configure(points: PackedVector3Array, color: Color)`.

- [ ] **Step 1: Add failing component tests**

```gdscript
# tests/visuals/test_geometric_components.gd
extends "res://tests/test_case.gd"

const ShipVisual = preload("res://scripts/visuals/ship_visual.gd")
const StarVisual = preload("res://scripts/visuals/star_visual.gd")
const PlanetVisual = preload("res://scripts/visuals/planet_visual.gd")
const ConnectionSegment = preload("res://scripts/visuals/connection_segment.gd")

func run() -> void:
    var ship := ShipVisual.new()
    ship.configure(&"war", Color.BLUE)
    assert_true(ship.get_node("Body").mesh is PrismMesh, "ship uses PrismMesh")
    assert_equal(ship.scale, Vector3.ONE * 1.3, "war ship scale")

    var star := StarVisual.new()
    star.configure(&"red", Color.GREEN, true)
    assert_true(star.get_node("Body").mesh is SphereMesh, "star uses SphereMesh")
    assert_true(star.get_node("OwnerRing").visible, "owned star has ring")

    var planet := PlanetVisual.new()
    planet.configure(&"ice", 1.2)
    assert_true(planet.get_node("Body").mesh is SphereMesh, "planet uses SphereMesh")

    var segment := ConnectionSegment.new()
    segment.configure_between(Vector3.ZERO, Vector3(10, 0, 0), 0.1, Color.WHITE)
    assert_equal(segment.position, Vector3(5, 0, 0), "segment midpoint")
    assert_equal(segment.get_node("Body").mesh.size.x, 10.0, "segment length")
```

Add the test preload to `TEST_SCRIPTS`, run the runner, and expect missing-script or missing-method failures.

- [ ] **Step 2: Implement shared materials and ring, star, ship, and planet components**

```gdscript
# scripts/visuals/material_factory.gd
class_name VisualMaterialFactory
extends RefCounted

static func create(color: Color, emission := false, transparent := false, unshaded := false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = emission
    material.emission = color
    if transparent:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if unshaded:
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material
```

```gdscript
# scripts/visuals/ring_visual.gd
class_name RingVisual
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")
var body: MeshInstance3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)

func configure(color: Color, radius := 0.8, shown := true) -> void:
    var torus := TorusMesh.new()
    torus.inner_radius = radius - 0.04
    torus.outer_radius = radius
    torus.rings = 16
    torus.ring_segments = 6
    body.mesh = torus
    body.material_override = Materials.create(color, true, false, true)
    visible = shown
```

```gdscript
# scripts/visuals/star_visual.gd
class_name StarVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")
var body: MeshInstance3D
var owner_ring: Node3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)
    owner_ring = Ring.new()
    owner_ring.name = "OwnerRing"
    add_child(owner_ring)

func configure(star_type: StringName, owner_color := Color(0, 0, 0, 0), selected := false) -> void:
    var style := Palette.star_style(star_type)
    var sphere := SphereMesh.new()
    sphere.radial_segments = 16
    sphere.rings = 8
    body.mesh = sphere
    body.material_override = Materials.create(style.color, true, false, true)
    scale = Vector3.ONE * style.scale
    owner_ring.configure(Palette.normalize_owner_color(owner_color), 0.75, owner_color.a > 0.0 or selected)
```

```gdscript
# scripts/visuals/ship_visual.gd
class_name ShipVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
const Ring = preload("res://scripts/visuals/ring_visual.gd")
var body: MeshInstance3D
var owner_ring: Node3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)
    owner_ring = Ring.new()
    owner_ring.name = "OwnerRing"
    add_child(owner_ring)

func configure(ship_class: StringName, owner_color := Color(0, 0, 0, 0)) -> void:
    var style := Palette.ship_style(ship_class)
    var prism := PrismMesh.new()
    prism.size = Vector3(0.8, 0.3, 1.4)
    body.mesh = prism
    body.material_override = Materials.create(style.color)
    scale = Vector3.ONE * style.scale
    owner_ring.configure(Palette.normalize_owner_color(owner_color), 0.65, true)

func set_direction(direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() > 0.0001:
        rotation.y = atan2(flat.x, flat.z)
```

```gdscript
# scripts/visuals/planet_visual.gd
class_name PlanetVisual
extends Node3D

const Palette = preload("res://scripts/visuals/visual_palette.gd")
const Materials = preload("res://scripts/visuals/material_factory.gd")
var body: MeshInstance3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)

func configure(planet_type: StringName, size := 1.0) -> void:
    var style := Palette.planet_style(planet_type)
    var sphere := SphereMesh.new()
    sphere.radial_segments = 12
    sphere.rings = 6
    body.mesh = sphere
    body.material_override = Materials.create(style.color, planet_type == &"volcanic")
    scale = Vector3.ONE * maxf(size, 0.1)
```

- [ ] **Step 3: Implement connection and Zodíaco geometry**

```gdscript
# scripts/visuals/connection_segment.gd
class_name ConnectionSegment
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")
var body: MeshInstance3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)

func configure_between(origin: Vector3, destination: Vector3, thickness: float, color: Color) -> void:
    var delta := destination - origin
    if delta.length_squared() <= 0.0001:
        visible = false
        return
    visible = true
    var box := BoxMesh.new()
    box.size = Vector3(delta.length(), thickness, thickness)
    body.mesh = box
    body.material_override = Materials.create(color, false, false, true)
    position = (origin + destination) * 0.5
    rotation.y = -atan2(delta.z, delta.x)
```

```gdscript
# scripts/visuals/zodiac_area_visual.gd
class_name ZodiacAreaVisual
extends Node3D

const Materials = preload("res://scripts/visuals/material_factory.gd")
var body: MeshInstance3D

func _init() -> void:
    body = MeshInstance3D.new()
    body.name = "Body"
    add_child(body)

func configure(points: PackedVector3Array, color: Color) -> void:
    if points.size() < 3:
        visible = false
        return
    var indices := PackedInt32Array()
    for index in range(1, points.size() - 1):
        indices.append_array(PackedInt32Array([0, index, index + 1]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points
    arrays[Mesh.ARRAY_INDEX] = indices
    var area_mesh := ArrayMesh.new()
    area_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    body.mesh = area_mesh
    body.material_override = Materials.create(Color(color, 0.22), false, true, true)
    visible = true
```

- [ ] **Step 4: Create the six parameterized `.tscn` resources**

Use this exact three-line scene pattern for each component, changing the script path and node name:

```ini
[gd_scene load_steps=2 format=3]
[ext_resource path="res://scripts/visuals/star_visual.gd" type="Script" id="1"]
[node name="StarVisual" type="Node3D"]
script = ExtResource("1")
```

Create equivalent resources for `RingVisual`, `ShipVisual`, `PlanetVisual`, `ConnectionSegment`, and `ZodiacAreaVisual`.

- [ ] **Step 5: Run the complete tests, commit, and push**

Run: `godot --headless --path . --script res://tests/test_runner.gd`

Expected: `TESTS PASSED`, exit code 0.

Commit: `feat: add reusable geometric visual components`

---

### Task 3: Demonstration scene and project entry point

**Files:**
- Create: `scripts/demo/geometric_visual_demo.gd`
- Create: `scenes/demo/geometric_visual_demo.tscn`
- Modify: `project.godot`
- Create: `tests/demo/test_geometric_visual_demo.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: all visual component `configure` methods from Task 2.
- Produces: a runnable `res://scenes/demo/geometric_visual_demo.tscn` showing every approved visual category.

- [ ] **Step 1: Add a failing composition test**

```gdscript
# tests/demo/test_geometric_visual_demo.gd
extends "res://tests/test_case.gd"

const DemoScene = preload("res://scenes/demo/geometric_visual_demo.tscn")

func run() -> void:
    var demo := DemoScene.instantiate()
    assert_true(demo.get_node_or_null("Stars") != null, "demo has stars")
    assert_true(demo.get_node_or_null("Ships") != null, "demo has ships")
    assert_true(demo.get_node_or_null("Planets") != null, "demo has planets")
    assert_true(demo.get_node_or_null("Connections") != null, "demo has connections")
    assert_true(demo.get_node_or_null("ZodiacArea") != null, "demo has zodiac area")
    demo.free()
```

Run the runner and expect preload failure because the demo scene does not exist.

- [ ] **Step 2: Build the demo composition**

```gdscript
# scripts/demo/geometric_visual_demo.gd
extends Node3D

const StarVisual = preload("res://scripts/visuals/star_visual.gd")
const ShipVisual = preload("res://scripts/visuals/ship_visual.gd")
const PlanetVisual = preload("res://scripts/visuals/planet_visual.gd")
const SegmentVisual = preload("res://scripts/visuals/connection_segment.gd")
const ZodiacVisual = preload("res://scripts/visuals/zodiac_area_visual.gd")
const OWNER_COLOR := Color("55a7ff")

func _init() -> void:
    _add_environment()
    var stars := _container("Stars")
    var ships := _container("Ships")
    var planets := _container("Planets")
    var connections := _container("Connections")
    var area := ZodiacVisual.new()
    area.name = "ZodiacArea"
    add_child(area)
    var points := PackedVector3Array([Vector3(-7, 0, -3), Vector3(0, 0, 5), Vector3(7, 0, -3)])
    area.configure(points, OWNER_COLOR)
    _add_stars(stars, points)
    _add_ships(ships)
    _add_planets(planets)
    _add_connections(connections, points)

func _container(node_name: String) -> Node3D:
    var container := Node3D.new()
    container.name = node_name
    add_child(container)
    return container
```

Append these concrete composition methods:

```gdscript
func _add_environment() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(0, 18, 18)
    camera.rotation_degrees = Vector3(-45, 0, 0)
    add_child(camera)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -30, 0)
    light.light_energy = 1.4
    add_child(light)
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("07111f")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("6688aa")
    environment.ambient_light_energy = 1.2
    world.environment = environment
    add_child(world)

func _add_stars(parent: Node3D, points: PackedVector3Array) -> void:
    var types := [&"red", &"yellow", &"blue"]
    for index in points.size():
        var star := StarVisual.new()
        star.position = points[index]
        star.configure(types[index], OWNER_COLOR, index == 1)
        parent.add_child(star)

func _add_ships(parent: Node3D) -> void:
    var classes := [&"expedition", &"colony", &"war"]
    for index in classes.size():
        var ship := ShipVisual.new()
        ship.position = Vector3(-3 + index * 3, 0.5, 0)
        ship.configure(classes[index], OWNER_COLOR)
        ship.set_direction(Vector3(1, 0, -1))
        parent.add_child(ship)

func _add_planets(parent: Node3D) -> void:
    var types := [&"rocky", &"gas", &"ice", &"volcanic"]
    for index in types.size():
        var planet := PlanetVisual.new()
        planet.position = Vector3(-6 + index * 4, 0.3, 8)
        planet.configure(types[index], 0.55 + index * 0.08)
        parent.add_child(planet)

func _add_connections(parent: Node3D, points: PackedVector3Array) -> void:
    for index in points.size():
        var segment := SegmentVisual.new()
        segment.configure_between(points[index], points[(index + 1) % points.size()], 0.09, OWNER_COLOR)
        parent.add_child(segment)
```

The scene resource is:

```ini
[gd_scene load_steps=2 format=3]
[ext_resource path="res://scripts/demo/geometric_visual_demo.gd" type="Script" id="1"]
[node name="GeometricVisualDemo" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 3: Configure the project entry point**

Add `run/main_scene="res://scenes/demo/geometric_visual_demo.tscn"` to `[application]` in `project.godot`.

- [ ] **Step 4: Verify headless tests and launch smoke check**

Run: `godot --headless --path . --script res://tests/test_runner.gd`

Expected: `TESTS PASSED`, exit code 0.

Run: `godot --headless --path . --quit-after 2`

Expected: exit code 0 with no parser, resource, or shader errors.

- [ ] **Step 5: Inspect the demo in the visible Godot editor, commit, and push**

Run the main scene in the already-open editor and confirm that stars, planets, all three ships, connections, and the Zodíaco are visible and distinguishable.

Commit: `feat: add geometric visual demo`

---

### Task 4: Final verification

**Files:**
- Modify only files requiring corrections discovered during verification.

- [ ] **Step 1: Run all automated checks**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --quit-after 2
git diff --check
```

Expected: both Godot commands exit 0, the runner prints `TESTS PASSED`, and `git diff --check` reports no errors.

- [ ] **Step 2: Confirm repository rules**

Check every handwritten file remains below 1,000 lines and `git status -sb` contains no unrelated files.

- [ ] **Step 3: Commit and push corrections if needed**

Use a focused `fix:` commit only when verification required a change. Do not create an empty commit.
