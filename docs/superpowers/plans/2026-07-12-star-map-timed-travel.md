# Star Map and Timed Travel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable Zodiakos engine slice: a deterministic 3D star map on the XZ plane where the player pans, zooms, selects an owned origin and visible destination, dispatches an expedition ship, watches timed travel, pauses the simulation, surveys the destination, and resumes the saved state.

**Architecture:** Keep deterministic game state in small `RefCounted` GDScript classes with no scene dependencies. Render that state through a thin Node3D presentation layer using an orthographic `Camera3D`, one `Area3D` per visible star, and 3D route/ship meshes. Persist a versioned dictionary through `FileAccess`; UI nodes issue commands through `GameSession` instead of changing simulation state directly.

**Tech Stack:** Godot 4.x, GDScript, Compatibility renderer, native Godot headless scripts for tests, JSON saves under `user://`.

## Global Constraints

- Run only on native Windows PowerShell, never through WSL.
- Set `$env:GODOT_BIN` to the installed Godot 4 editor executable before running commands.
- Use 3D presentation on the XZ plane with an orthographic `Camera3D`.
- Use deterministic seed `20260712` for the default starter region.
- The player begins with one owned home star and one reusable level-1 expedition ship.
- Any visible star may be targeted without prior surveying.
- Expedition travel has time and range but no fuel or per-trip fee.
- Pause freezes game time and every active order; there is no fast-forward.
- Keep simulation code independent from Node, SceneTree, rendering, input, and wall-clock time.
- Add no third-party testing plugin in this milestone.
- Follow red-green-refactor for every production behavior.
- Official references: [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html), [3D ray casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html), and [runtime file access](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html).

## Planned File Structure

```text
project.godot
scenes/main/main.tscn
scripts/domain/star_field_generator.gd
scripts/domain/ship_profiles.gd
scripts/domain/selection_state.gd
scripts/simulation/game_simulation.gd
scripts/simulation/game_session.gd
scripts/persistence/save_repository.gd
scripts/presentation/map_camera.gd
scripts/presentation/star_view.gd
scripts/presentation/route_view.gd
scripts/presentation/main.gd
tests/test_case.gd
tests/test_runner.gd
tests/unit/test_star_field_generator.gd
tests/unit/test_game_simulation.gd
tests/unit/test_game_session.gd
tests/unit/test_save_repository.gd
tests/unit/test_main_scene.gd
```

---

### Task 1: Bootstrap the Godot project and native test harness

**Files:**
- Create: `project.godot`
- Create: `scenes/main/main.tscn`
- Create: `tests/test_case.gd`
- Create: `tests/test_runner.gd`

**Interfaces:**
- Produces: PowerShell test command `& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd`.
- Produces: Test classes extending `res://tests/test_case.gd` with `run() -> void` and `failures: Array[String]`.

- [ ] **Step 1: Verify the Godot executable**

Run:

```powershell
if (-not $env:GODOT_BIN) { throw 'Set GODOT_BIN to the installed Godot 4 editor executable.' }
& $env:GODOT_BIN --version
```

Expected: exit code `0` and a version beginning with `4.`.

- [ ] **Step 2: Create the project configuration**

Create `project.godot`:

```ini
; Engine configuration file.
; Edit through the Godot editor when possible.

config_version=5

[application]

config/name="Zodiakos"
run/main_scene="res://scenes/main/main.tscn"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.004, 0.006, 0.035, 1)
```

Create `scenes/main/main.tscn`:

```ini
[gd_scene format=3]

[node name="Main" type="Node3D"]
```

- [ ] **Step 3: Create the reusable test base**

Create `tests/test_case.gd`:

```gdscript
extends RefCounted

var failures: Array[String] = []

func expect_true(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func expect_false(value: bool, message: String) -> void:
    if value:
        failures.append(message)

func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        failures.append("%s | expected=%s actual=%s" % [message, expected, actual])

func expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
    if absf(actual - expected) > tolerance:
        failures.append("%s | expected=%s actual=%s" % [message, expected, actual])

func run() -> void:
    pass
```

Create `tests/test_runner.gd`:

```gdscript
extends SceneTree

const TEST_PATHS: Array[String] = []

func _init() -> void:
    var all_failures: Array[String] = []
    for path in TEST_PATHS:
        var script: Script = load(path)
        if script == null:
            all_failures.append("Could not load %s" % path)
            continue
        var test_case: RefCounted = script.new()
        test_case.run()
        for failure in test_case.failures:
            all_failures.append("%s: %s" % [path, failure])

    if all_failures.is_empty():
        print("PASS: %d test files" % TEST_PATHS.size())
        quit(0)
        return

    for failure in all_failures:
        printerr("FAIL: %s" % failure)
    quit(1)
```

- [ ] **Step 4: Import and run the empty suite**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --import
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 0 test files` and exit code `0`.

- [ ] **Step 5: Commit the bootstrap**

```powershell
git add project.godot scenes/main/main.tscn tests/test_case.gd tests/test_runner.gd
git commit -m "build: bootstrap Godot project"
```

---

### Task 2: Generate a deterministic starter star field

**Files:**
- Create: `tests/unit/test_star_field_generator.gd`
- Create: `scripts/domain/star_field_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `StarFieldGenerator.generate_starter_region(seed: int) -> Array[Dictionary]`.
- Star dictionary keys: `id: String`, `name: String`, `position: Vector2`, `owned: bool`, `surveyed: bool`.

- [ ] **Step 1: Register and write the failing generator test**

Change `TEST_PATHS` in `tests/test_runner.gd` to:

```gdscript
const TEST_PATHS: Array[String] = [
    "res://tests/unit/test_star_field_generator.gd",
]
```

Create `tests/unit/test_star_field_generator.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
    var generator_script: Script = load("res://scripts/domain/star_field_generator.gd")
    expect_true(generator_script != null, "generator script should exist")
    if generator_script == null:
        return

    var first: Array = generator_script.generate_starter_region(20260712)
    var second: Array = generator_script.generate_starter_region(20260712)
    var other: Array = generator_script.generate_starter_region(99)

    expect_equal(first, second, "same seed should generate identical stars")
    expect_false(first == other, "different seed should change optional stars")
    expect_equal(first.size(), 8, "starter region should contain eight stars")
    expect_equal(first[0]["id"], "home", "first star should be the home system")
    expect_true(first[0]["owned"], "home system should start owned")
    expect_true(first[0]["surveyed"], "home system should start surveyed")

    var a: Vector2 = first[0]["position"]
    var b: Vector2 = first[1]["position"]
    var c: Vector2 = first[2]["position"]
    expect_true(a.distance_to(b) <= 64.0, "first candidate must be in base range")
    expect_true(b.distance_to(c) <= 64.0, "candidate edge must be in base range")
    expect_true(c.distance_to(a) <= 64.0, "closing edge must be in base range")
    var twice_area: float = absf((b - a).cross(c - a))
    expect_true(twice_area >= 800.0, "starter triangle must be visually legible")
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
```

Expected: FAIL with `generator script should exist`.

- [ ] **Step 3: Implement deterministic generation**

Create `scripts/domain/star_field_generator.gd`:

```gdscript
class_name StarFieldGenerator
extends RefCounted

const STAR_COUNT := 8

static func generate_starter_region(seed: int) -> Array[Dictionary]:
    var stars: Array[Dictionary] = [
        _star("home", "Origem", Vector2.ZERO, true, true),
        _star("candidate-a", "Aster", Vector2(42.0, 4.0), false, false),
        _star("candidate-b", "Boreal", Vector2(18.0, 40.0), false, false),
    ]

    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    for index in range(3, STAR_COUNT):
        var angle := rng.randf_range(0.0, TAU)
        var radius := rng.randf_range(72.0, 150.0)
        var position := Vector2(cos(angle), sin(angle)) * radius
        stars.append(_star("star-%d" % index, "Sistema %d" % index, position, false, false))
    return stars

static func _star(id: String, display_name: String, position: Vector2, owned: bool, surveyed: bool) -> Dictionary:
    return {
        "id": id,
        "name": display_name,
        "position": position,
        "owned": owned,
        "surveyed": surveyed,
    }
```

- [ ] **Step 4: Run the suite and verify GREEN**

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 1 test files`.

- [ ] **Step 5: Commit deterministic generation**

```powershell
git add tests/test_runner.gd tests/unit/test_star_field_generator.gd scripts/domain/star_field_generator.gd
git commit -m "feat: generate deterministic starter stars"
```

---

### Task 3: Implement pause-aware timed travel

**Files:**
- Create: `tests/unit/test_game_simulation.gd`
- Create: `scripts/domain/ship_profiles.gd`
- Create: `scripts/simulation/game_simulation.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `ShipProfiles.expedition_level_1() -> Dictionary`.
- Produces: `GameSimulation.dispatch(profile, origin_id, origin, destination_id, destination) -> Dictionary`.
- Produces: `GameSimulation.advance(delta: float) -> void`.
- Produces: `GameSimulation.set_paused(value: bool) -> void`.
- Produces: `GameSimulation.get_order_position(order_id: String) -> Vector2`.

- [ ] **Step 1: Write the failing timed-travel test**

Append `"res://tests/unit/test_game_simulation.gd"` to `TEST_PATHS`.

Create `tests/unit/test_game_simulation.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
    var simulation_script: Script = load("res://scripts/simulation/game_simulation.gd")
    var profiles_script: Script = load("res://scripts/domain/ship_profiles.gd")
    expect_true(simulation_script != null, "simulation script should exist")
    expect_true(profiles_script != null, "ship profiles should exist")
    if simulation_script == null or profiles_script == null:
        return

    var simulation: RefCounted = simulation_script.new()
    var profile: Dictionary = profiles_script.expedition_level_1()
    var order: Dictionary = simulation.dispatch(
        profile,
        "home",
        Vector2.ZERO,
        "candidate-a",
        Vector2(42.0, 0.0)
    )

    expect_true(not order.is_empty(), "valid expedition should dispatch")
    expect_near(order["duration"], 28.0, 0.001, "42 units at 1.5 speed should take 28 seconds")

    simulation.advance(14.0)
    expect_near(simulation.get_order_position(order["id"]).x, 21.0, 0.001, "ship should be halfway")

    simulation.set_paused(true)
    simulation.advance(10.0)
    expect_near(simulation.get_order_position(order["id"]).x, 21.0, 0.001, "pause should freeze travel")

    simulation.set_paused(false)
    simulation.advance(14.0)
    expect_equal(order["state"], "completed", "order should complete after remaining time")
    expect_true(simulation.surveyed.get("candidate-a", false), "expedition arrival should survey destination")

    var too_far: Dictionary = simulation.dispatch(
        profile,
        "home",
        Vector2.ZERO,
        "far",
        Vector2(200.0, 0.0)
    )
    expect_true(too_far.is_empty(), "dispatch beyond range should be rejected")
```

- [ ] **Step 2: Run the test and verify RED**

Run the suite. Expected: FAIL because both production scripts are missing.

- [ ] **Step 3: Implement expedition stats**

Create `scripts/domain/ship_profiles.gd`:

```gdscript
class_name ShipProfiles
extends RefCounted

static func expedition_level_1() -> Dictionary:
    return {
        "id": "expedition-1",
        "display_name": "Expedição Nível 1",
        "action": "survey",
        "speed": 1.5,
        "max_range": 90.0,
        "build_credits": 60,
        "build_metal": 5,
        "build_energy": 5,
        "build_progress": 30,
        "combat": 0,
        "defense": 1,
    }
```

Create `scripts/simulation/game_simulation.gd`:

```gdscript
class_name GameSimulation
extends RefCounted

var game_time := 0.0
var paused := false
var next_order_number := 1
var orders: Array[Dictionary] = []
var surveyed: Dictionary = {"home": true}

func dispatch(
    profile: Dictionary,
    origin_id: String,
    origin: Vector2,
    destination_id: String,
    destination: Vector2
) -> Dictionary:
    var distance := origin.distance_to(destination)
    if distance > float(profile["max_range"]):
        return {}
    var order: Dictionary = {
        "id": "order-%d" % next_order_number,
        "profile_id": profile["id"],
        "action": profile["action"],
        "origin_id": origin_id,
        "origin": origin,
        "destination_id": destination_id,
        "destination": destination,
        "duration": distance / float(profile["speed"]),
        "elapsed": 0.0,
        "state": "traveling",
    }
    next_order_number += 1
    orders.append(order)
    return order

func advance(delta: float) -> void:
    if paused or delta <= 0.0:
        return
    game_time += delta
    for order in orders:
        if order["state"] != "traveling":
            continue
        order["elapsed"] = minf(float(order["elapsed"]) + delta, float(order["duration"]))
        if is_equal_approx(float(order["elapsed"]), float(order["duration"])):
            order["state"] = "completed"
            if order["action"] == "survey":
                surveyed[order["destination_id"]] = true

func set_paused(value: bool) -> void:
    paused = value

func get_order(order_id: String) -> Dictionary:
    for order in orders:
        if order["id"] == order_id:
            return order
    return {}

func get_order_position(order_id: String) -> Vector2:
    var order := get_order(order_id)
    if order.is_empty():
        return Vector2.ZERO
    var duration := float(order["duration"])
    var ratio := 1.0 if duration <= 0.0 else float(order["elapsed"]) / duration
    var origin: Vector2 = order["origin"]
    var destination: Vector2 = order["destination"]
    return origin.lerp(destination, ratio)
```

- [ ] **Step 4: Run the suite and verify GREEN**

Expected: `PASS: 2 test files`.

- [ ] **Step 5: Commit timed travel**

```powershell
git add tests/test_runner.gd tests/unit/test_game_simulation.gd scripts/domain/ship_profiles.gd scripts/simulation/game_simulation.gd
git commit -m "feat: add pause-aware expedition travel"
```

---

### Task 4: Add selection and the playable game session

**Files:**
- Create: `tests/unit/test_game_session.gd`
- Create: `scripts/domain/selection_state.gd`
- Create: `scripts/simulation/game_session.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `SelectionState.select_star(star: Dictionary) -> bool`.
- Produces: `SelectionState.can_dispatch() -> bool`.
- Produces: `GameSession.new_game(seed: int) -> void`.
- Produces: `GameSession.dispatch_expedition() -> Dictionary`.
- Produces: `GameSession.get_eta() -> float`.

- [ ] **Step 1: Write the failing session test**

Append `"res://tests/unit/test_game_session.gd"` to `TEST_PATHS`.

Create `tests/unit/test_game_session.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
    var session_script: Script = load("res://scripts/simulation/game_session.gd")
    expect_true(session_script != null, "game session should exist")
    if session_script == null:
        return

    var session: RefCounted = session_script.new()
    session.new_game(20260712)
    expect_equal(session.stars.size(), 8, "new game should generate starter stars")
    expect_equal(session.selection.origin_id, "", "selection should begin empty")

    expect_false(session.select_star("candidate-a"), "unowned star cannot be the origin")
    expect_true(session.select_star("home"), "owned home should become origin")
    expect_true(session.select_star("candidate-a"), "visible candidate should become destination")
    expect_true(session.selection.can_dispatch(), "origin and destination should enable dispatch")
    expect_near(session.get_eta(), 28.0, 0.001, "session should expose expedition ETA")

    var order: Dictionary = session.dispatch_expedition()
    expect_true(not order.is_empty(), "session should dispatch expedition")
    session.advance(28.0)
    expect_true(session.simulation.surveyed.get("candidate-a", false), "arrival should survey through session")
```

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL with `game session should exist`.

- [ ] **Step 3: Implement selection state**

Create `scripts/domain/selection_state.gd`:

```gdscript
class_name SelectionState
extends RefCounted

var origin_id := ""
var destination_id := ""

func select_star(star: Dictionary) -> bool:
    var id := String(star["id"])
    if origin_id.is_empty():
        if not bool(star["owned"]):
            return false
        origin_id = id
        destination_id = ""
        return true
    if id == origin_id:
        destination_id = ""
        return true
    destination_id = id
    return true

func can_dispatch() -> bool:
    return not origin_id.is_empty() and not destination_id.is_empty()

func clear() -> void:
    origin_id = ""
    destination_id = ""
```

Create `scripts/simulation/game_session.gd`:

```gdscript
class_name GameSession
extends RefCounted

const Generator = preload("res://scripts/domain/star_field_generator.gd")
const Profiles = preload("res://scripts/domain/ship_profiles.gd")
const Simulation = preload("res://scripts/simulation/game_simulation.gd")
const Selection = preload("res://scripts/domain/selection_state.gd")

var seed := 0
var stars: Array[Dictionary] = []
var stars_by_id: Dictionary = {}
var simulation: RefCounted
var selection: RefCounted

func new_game(value: int) -> void:
    seed = value
    stars = Generator.generate_starter_region(seed)
    stars_by_id.clear()
    for star in stars:
        stars_by_id[star["id"]] = star
    simulation = Simulation.new()
    selection = Selection.new()

func select_star(id: String) -> bool:
    if not stars_by_id.has(id):
        return false
    return selection.select_star(stars_by_id[id])

func get_eta() -> float:
    if not selection.can_dispatch():
        return 0.0
    var profile: Dictionary = Profiles.expedition_level_1()
    var origin: Vector2 = stars_by_id[selection.origin_id]["position"]
    var destination: Vector2 = stars_by_id[selection.destination_id]["position"]
    return origin.distance_to(destination) / float(profile["speed"])

func dispatch_expedition() -> Dictionary:
    if not selection.can_dispatch():
        return {}
    var origin: Dictionary = stars_by_id[selection.origin_id]
    var destination: Dictionary = stars_by_id[selection.destination_id]
    return simulation.dispatch(
        Profiles.expedition_level_1(),
        origin["id"],
        origin["position"],
        destination["id"],
        destination["position"]
    )

func advance(delta: float) -> void:
    simulation.advance(delta)
```

- [ ] **Step 4: Run the suite and verify GREEN**

Expected: `PASS: 3 test files`.

- [ ] **Step 5: Commit the game session**

```powershell
git add tests/test_runner.gd tests/unit/test_game_session.gd scripts/domain/selection_state.gd scripts/simulation/game_session.gd
git commit -m "feat: add origin destination game session"
```

---

### Task 5: Persist and restore the engine state

**Files:**
- Create: `tests/unit/test_save_repository.gd`
- Create: `scripts/persistence/save_repository.gd`
- Modify: `scripts/simulation/game_simulation.gd`
- Modify: `scripts/simulation/game_session.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `GameSimulation.to_dict() -> Dictionary` and `GameSimulation.restore(data: Dictionary) -> void`.
- Produces: `GameSession.to_dict() -> Dictionary` and `GameSession.restore(data: Dictionary) -> void`.
- Produces: `SaveRepository.save_session(session, path := "user://savegame.json") -> Error`.
- Produces: `SaveRepository.load_session(path := "user://savegame.json") -> RefCounted`.

- [ ] **Step 1: Write the failing save round-trip test**

Append `"res://tests/unit/test_save_repository.gd"` to `TEST_PATHS`.

Create `tests/unit/test_save_repository.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
    var session_script: Script = load("res://scripts/simulation/game_session.gd")
    var repository_script: Script = load("res://scripts/persistence/save_repository.gd")
    expect_true(repository_script != null, "save repository should exist")
    if repository_script == null:
        return

    var path := "user://zodiakos-test-save.json"
    var session: RefCounted = session_script.new()
    session.new_game(20260712)
    session.select_star("home")
    session.select_star("candidate-a")
    var order: Dictionary = session.dispatch_expedition()
    session.advance(9.0)
    session.simulation.set_paused(true)

    expect_equal(repository_script.save_session(session, path), OK, "save should succeed")
    var loaded: RefCounted = repository_script.load_session(path)
    expect_true(loaded != null, "load should return a session")
    if loaded != null:
        expect_equal(loaded.seed, 20260712, "seed should survive save")
        expect_true(loaded.simulation.paused, "pause state should survive save")
        expect_near(loaded.simulation.game_time, 9.0, 0.001, "game time should survive save")
        expect_near(float(loaded.simulation.get_order(order["id"])["elapsed"]), 9.0, 0.001, "travel progress should survive save")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL with `save repository should exist`.

- [ ] **Step 3: Add serialization to simulation and session**

Add to `scripts/simulation/game_simulation.gd`:

```gdscript
func to_dict() -> Dictionary:
    var encoded_orders: Array[Dictionary] = []
    for order in orders:
        var encoded := order.duplicate(true)
        encoded["origin"] = [order["origin"].x, order["origin"].y]
        encoded["destination"] = [order["destination"].x, order["destination"].y]
        encoded_orders.append(encoded)
    return {
        "game_time": game_time,
        "paused": paused,
        "next_order_number": next_order_number,
        "orders": encoded_orders,
        "surveyed": surveyed.duplicate(true),
    }

func restore(data: Dictionary) -> void:
    game_time = float(data["game_time"])
    paused = bool(data["paused"])
    next_order_number = int(data["next_order_number"])
    surveyed = Dictionary(data["surveyed"]).duplicate(true)
    orders.clear()
    for raw in data["orders"]:
        var order: Dictionary = Dictionary(raw).duplicate(true)
        order["origin"] = Vector2(float(raw["origin"][0]), float(raw["origin"][1]))
        order["destination"] = Vector2(float(raw["destination"][0]), float(raw["destination"][1]))
        orders.append(order)
```

Add to `scripts/simulation/game_session.gd`:

```gdscript
func to_dict() -> Dictionary:
    return {
        "version": 1,
        "seed": seed,
        "simulation": simulation.to_dict(),
    }

func restore(data: Dictionary) -> void:
    new_game(int(data["seed"]))
    simulation.restore(data["simulation"])
```

- [ ] **Step 4: Implement JSON persistence**

Create `scripts/persistence/save_repository.gd`:

```gdscript
class_name SaveRepository
extends RefCounted

const Session = preload("res://scripts/simulation/game_session.gd")

static func save_session(session: RefCounted, path := "user://savegame.json") -> Error:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(session.to_dict()))
    file.close()
    return OK

static func load_session(path := "user://savegame.json") -> RefCounted:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return null
    var data: Dictionary = parsed
    if int(data.get("version", 0)) != 1:
        return null
    var session: RefCounted = Session.new()
    session.restore(data)
    return session
```

- [ ] **Step 5: Run the suite and verify GREEN**

Expected: `PASS: 4 test files`.

- [ ] **Step 6: Commit persistence**

```powershell
git add tests/test_runner.gd tests/unit/test_save_repository.gd scripts/simulation/game_simulation.gd scripts/simulation/game_session.gd scripts/persistence/save_repository.gd
git commit -m "feat: persist star map travel state"
```

---

### Task 6: Render the interactive 3D star map

**Files:**
- Create: `tests/unit/test_main_scene.gd`
- Create: `scripts/presentation/map_camera.gd`
- Create: `scripts/presentation/star_view.gd`
- Create: `scripts/presentation/route_view.gd`
- Create: `scripts/presentation/main.gd`
- Modify: `scenes/main/main.tscn`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `StarView.setup(star: Dictionary) -> void` and signal `clicked(star_id: String)`.
- Produces: `RouteView.show_route(origin: Vector2, destination: Vector2, valid: bool) -> void`.
- Consumes: `GameSession` for generated stars and simulation state.

- [ ] **Step 1: Write the failing scene structure test**

Append `"res://tests/unit/test_main_scene.gd"` to `TEST_PATHS`.

Create `tests/unit/test_main_scene.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
    var scene: PackedScene = load("res://scenes/main/main.tscn")
    expect_true(scene != null, "main scene should load")
    if scene == null:
        return
    var root: Node = scene.instantiate()
    expect_true(root.has_node("Camera3D"), "main scene needs Camera3D")
    expect_true(root.has_node("Stars"), "main scene needs Stars container")
    expect_true(root.has_node("Ships"), "main scene needs Ships container")
    expect_true(root.has_node("RouteView"), "main scene needs route preview")
    expect_true(root.has_node("HUD/Panel/VBox/DispatchButton"), "HUD needs dispatch button")
    expect_true(root.has_node("HUD/Panel/VBox/PauseButton"), "HUD needs pause button")
    root.free()
```

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because required scene nodes do not exist.

- [ ] **Step 3: Implement the orthographic map camera**

Create `scripts/presentation/map_camera.gd`:

```gdscript
extends Camera3D

const MIN_SIZE := 45.0
const MAX_SIZE := 320.0
const PAN_SCALE := 0.12

var dragging := false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_MIDDLE:
            dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            size = maxf(MIN_SIZE, size * 0.9)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            size = minf(MAX_SIZE, size * 1.1)
    elif event is InputEventMouseMotion and dragging:
        var scale := size * PAN_SCALE / 100.0
        global_position += Vector3(-event.relative.x * scale, 0.0, -event.relative.y * scale)
```

Create `scripts/presentation/star_view.gd`:

```gdscript
class_name StarView
extends Area3D

signal clicked(star_id: String)

var star: Dictionary
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

func _ready() -> void:
    input_ray_pickable = true
    mesh_instance = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.4
    sphere.height = 2.8
    mesh_instance.mesh = sphere
    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh_instance.material_override = material
    add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.2
    collision.shape = shape
    add_child(collision)

    input_event.connect(_on_input_event)

func setup(value: Dictionary) -> void:
    star = value
    position = Vector3(value["position"].x, 0.0, value["position"].y)
    if is_node_ready():
        _apply_color()

func set_selected(value: bool) -> void:
    if material != null:
        material.albedo_color = Color.WHITE if value else _base_color()

func _apply_color() -> void:
    material.albedo_color = _base_color()

func _base_color() -> Color:
    if star.get("owned", false):
        return Color(0.2, 0.85, 1.0)
    if star.get("surveyed", false):
        return Color(0.8, 0.55, 1.0)
    return Color(0.95, 0.95, 1.0)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(String(star["id"]))
```

Create `scripts/presentation/route_view.gd`:

```gdscript
class_name RouteView
extends MeshInstance3D

var immediate := ImmediateMesh.new()
var material := StandardMaterial3D.new()

func _ready() -> void:
    mesh = immediate
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true

func show_route(origin: Vector2, destination: Vector2, valid: bool) -> void:
    immediate.clear_surfaces()
    immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
    var color := Color(0.2, 1.0, 0.55) if valid else Color(1.0, 0.2, 0.25)
    immediate.surface_set_color(color)
    immediate.surface_add_vertex(Vector3(origin.x, 0.4, origin.y))
    immediate.surface_set_color(color)
    immediate.surface_add_vertex(Vector3(destination.x, 0.4, destination.y))
    immediate.surface_end()

func clear_route() -> void:
    immediate.clear_surfaces()
```

- [ ] **Step 4: Build the main scene**

Replace `scenes/main/main.tscn` with:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource path="res://scripts/presentation/main.gd" type="Script" id="1"]
[ext_resource path="res://scripts/presentation/map_camera.gd" type="Script" id="2"]
[ext_resource path="res://scripts/presentation/route_view.gd" type="Script" id="3"]

[node name="Main" type="Node3D"]
script = ExtResource("1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.573576, 0.819152, 0, -0.819152, 0.573576, 0, 110, 78)
projection = 1
size = 150.0
near = 0.1
far = 500.0
current = true
script = ExtResource("2")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-60, -25, 0)
light_energy = 0.8

[node name="Stars" type="Node3D" parent="."]

[node name="Ships" type="Node3D" parent="."]

[node name="RouteView" type="MeshInstance3D" parent="."]
script = ExtResource("3")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="Panel" type="PanelContainer" parent="HUD"]
offset_left = 20.0
offset_top = 20.0
offset_right = 380.0
offset_bottom = 250.0

[node name="VBox" type="VBoxContainer" parent="HUD/Panel"]

[node name="Title" type="Label" parent="HUD/Panel/VBox"]
text = "Zodiakos - Mapa Estratégico"

[node name="OriginLabel" type="Label" parent="HUD/Panel/VBox"]
text = "Origem: selecione uma estrela controlada"

[node name="DestinationLabel" type="Label" parent="HUD/Panel/VBox"]
text = "Destino: selecione uma estrela"

[node name="EtaLabel" type="Label" parent="HUD/Panel/VBox"]
text = "ETA: --"

[node name="DispatchButton" type="Button" parent="HUD/Panel/VBox"]
text = "Enviar expedição"
disabled = true

[node name="PauseButton" type="Button" parent="HUD/Panel/VBox"]
text = "Pausar"

[node name="StatusLabel" type="Label" parent="HUD/Panel/VBox"]
text = "Selecione a estrela Origem."
```

- [ ] **Step 5: Add a minimal presenter that spawns stars**

Create `scripts/presentation/main.gd`:

```gdscript
extends Node3D

const Session = preload("res://scripts/simulation/game_session.gd")
const StarViewScript = preload("res://scripts/presentation/star_view.gd")

@onready var stars_root: Node3D = $Stars

var session: RefCounted
var star_views: Dictionary = {}

func _ready() -> void:
    session = Session.new()
    session.new_game(20260712)
    for star in session.stars:
        var view: Area3D = StarViewScript.new()
        stars_root.add_child(view)
        view.setup(star)
        view.clicked.connect(_on_star_clicked)
        star_views[star["id"]] = view

func _on_star_clicked(star_id: String) -> void:
    session.select_star(star_id)
```

- [ ] **Step 6: Run the tests and the visual scene**

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
& $env:GODOT_BIN --path .
```

Expected: `PASS: 5 test files`; a 1280x720 window shows eight 3D stars, supports middle-mouse pan and wheel zoom, and accepts star clicks without errors.

- [ ] **Step 7: Commit the 3D map**

```powershell
git add tests/test_runner.gd tests/unit/test_main_scene.gd scenes/main/main.tscn scripts/presentation
git commit -m "feat: render interactive 3D star map"
```

---

### Task 7: Connect selection, route preview, dispatch, pause, and save

**Files:**
- Modify: `scripts/presentation/main.gd`
- Modify: `scripts/presentation/star_view.gd`
- Test: all existing headless tests plus manual scene verification

**Interfaces:**
- Consumes: `GameSession.select_star`, `get_eta`, `dispatch_expedition`, `advance`.
- Consumes: `SaveRepository.save_session` and `load_session`.
- Produces: a playable map flow from origin selection through surveyed arrival.

- [ ] **Step 1: Extend the session test with the expected UI-facing state**

Add these assertions to `tests/unit/test_game_session.gd` after destination selection:

```gdscript
    expect_equal(session.get_selected_origin()["id"], "home", "presenter should read selected origin")
    expect_equal(session.get_selected_destination()["id"], "candidate-a", "presenter should read selected destination")
    expect_true(session.can_dispatch_expedition(), "presenter should know expedition is valid")
```

Run the suite.

Expected: FAIL because the three methods do not exist.

- [ ] **Step 2: Add the minimal UI-facing session API**

Add to `scripts/simulation/game_session.gd`:

```gdscript
func get_selected_origin() -> Dictionary:
    return stars_by_id.get(selection.origin_id, {})

func get_selected_destination() -> Dictionary:
    return stars_by_id.get(selection.destination_id, {})

func can_dispatch_expedition() -> bool:
    if not selection.can_dispatch():
        return false
    var profile: Dictionary = Profiles.expedition_level_1()
    var origin: Vector2 = get_selected_origin()["position"]
    var destination: Vector2 = get_selected_destination()["position"]
    return origin.distance_to(destination) <= float(profile["max_range"])
```

Run the suite.

Expected: `PASS: 5 test files`.

- [ ] **Step 3: Replace the presenter with complete interaction code**

Replace `scripts/presentation/main.gd` with:

```gdscript
extends Node3D

const Session = preload("res://scripts/simulation/game_session.gd")
const Repository = preload("res://scripts/persistence/save_repository.gd")
const StarViewScript = preload("res://scripts/presentation/star_view.gd")

@onready var stars_root: Node3D = $Stars
@onready var ships_root: Node3D = $Ships
@onready var route_view: MeshInstance3D = $RouteView
@onready var origin_label: Label = $HUD/Panel/VBox/OriginLabel
@onready var destination_label: Label = $HUD/Panel/VBox/DestinationLabel
@onready var eta_label: Label = $HUD/Panel/VBox/EtaLabel
@onready var dispatch_button: Button = $HUD/Panel/VBox/DispatchButton
@onready var pause_button: Button = $HUD/Panel/VBox/PauseButton
@onready var status_label: Label = $HUD/Panel/VBox/StatusLabel

var session: RefCounted
var star_views: Dictionary = {}
var ship_views: Dictionary = {}

func _ready() -> void:
    session = Repository.load_session()
    if session == null:
        session = Session.new()
        session.new_game(20260712)
    _spawn_stars()
    dispatch_button.pressed.connect(_dispatch)
    pause_button.pressed.connect(_toggle_pause)
    get_tree().auto_accept_quit = false
    _refresh_hud()

func _process(delta: float) -> void:
    session.advance(delta)
    for order in session.simulation.orders:
        if not ship_views.has(order["id"]):
            _spawn_ship(order)
        var position: Vector2 = session.simulation.get_order_position(order["id"])
        ship_views[order["id"]].position = Vector3(position.x, 1.0, position.y)
        if order["state"] == "completed":
            ship_views[order["id"]].visible = false
            status_label.text = "%s foi sondado." % session.stars_by_id[order["destination_id"]]["name"]
            star_views[order["destination_id"]].star["surveyed"] = true
            star_views[order["destination_id"]]._apply_color()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        Repository.save_session(session)
        get_tree().quit()

func _spawn_stars() -> void:
    for star in session.stars:
        var view: Area3D = StarViewScript.new()
        stars_root.add_child(view)
        view.setup(star)
        view.clicked.connect(_on_star_clicked)
        star_views[star["id"]] = view

func _spawn_ship(order: Dictionary) -> void:
    var ship := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.2, 0.6, 2.4)
    ship.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.3, 1.0, 0.75)
    material.emission_enabled = true
    material.emission = Color(0.1, 0.6, 0.4)
    ship.material_override = material
    ships_root.add_child(ship)
    ship_views[order["id"]] = ship

func _on_star_clicked(star_id: String) -> void:
    if not session.select_star(star_id):
        status_label.text = "Selecione primeiro uma estrela controlada."
        return
    _refresh_hud()

func _refresh_hud() -> void:
    for id in star_views:
        var selected := id == session.selection.origin_id or id == session.selection.destination_id
        star_views[id].set_selected(selected)

    var origin := session.get_selected_origin()
    var destination := session.get_selected_destination()
    origin_label.text = "Origem: %s" % origin.get("name", "selecione")
    destination_label.text = "Destino: %s" % destination.get("name", "selecione")
    dispatch_button.disabled = not session.can_dispatch_expedition()

    if origin.is_empty() or destination.is_empty():
        eta_label.text = "ETA: --"
        route_view.clear_route()
        return

    var valid := session.can_dispatch_expedition()
    eta_label.text = "ETA: %.1f s" % session.get_eta()
    route_view.show_route(origin["position"], destination["position"], valid)

func _dispatch() -> void:
    var order := session.dispatch_expedition()
    if order.is_empty():
        status_label.text = "Destino fora do alcance."
        return
    status_label.text = "Expedição enviada. ETA %.1f s." % order["duration"]
    Repository.save_session(session)

func _toggle_pause() -> void:
    session.simulation.set_paused(not session.simulation.paused)
    pause_button.text = "Continuar" if session.simulation.paused else "Pausar"
    status_label.text = "Simulação pausada." if session.simulation.paused else "Simulação retomada."
    Repository.save_session(session)
```

- [ ] **Step 4: Run automated verification**

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
& $env:GODOT_BIN --headless --path . --quit-after 5
```

Expected: `PASS: 5 test files`; project starts headlessly and exits after five frames without parse or runtime errors.

- [ ] **Step 5: Run the manual acceptance flow**

```powershell
& $env:GODOT_BIN --path .
```

Verify in order:

1. Middle-drag pans and wheel zooms.
2. Clicking an unowned star first is rejected.
3. Clicking `Origem` then `Aster` shows a green route and ETA near 28 seconds.
4. Clicking `Enviar expedição` creates a moving 3D ship.
5. Clicking `Pausar` freezes ship position and ETA progress.
6. Clicking `Continuar` resumes movement.
7. Arrival changes Aster's state to surveyed.
8. Closing and reopening restores game time, pause state, surveying, and active travel.

- [ ] **Step 6: Commit the playable slice**

```powershell
git add scripts/simulation/game_session.gd scripts/presentation/main.gd
git commit -m "feat: make timed expedition loop playable"
```

---

### Task 8: Document operation and verify the milestone

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-07-12-zodiakos-first-15-minutes-design.md` only if playtesting changes an approved rule

**Interfaces:**
- Produces: exact Windows commands for opening, testing, and running the game.
- Produces: verification evidence for the engine milestone.

- [ ] **Step 1: Add Windows development commands to README**

Append:

````markdown
## Desenvolvimento no Windows

Defina `GODOT_BIN` com o caminho absoluto do executável instalado do Godot 4 e valide antes de continuar:

```powershell
if (-not $env:GODOT_BIN) { throw 'GODOT_BIN não está definido.' }
if (-not (Test-Path -LiteralPath $env:GODOT_BIN)) { throw 'GODOT_BIN não aponta para um arquivo existente.' }
& $env:GODOT_BIN --version
```

Executar testes:

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
```

Abrir o editor:

```powershell
& $env:GODOT_BIN --editor --path .
```

Executar o jogo:

```powershell
& $env:GODOT_BIN --path .
```
````

- [ ] **Step 2: Run the complete verification gate**

```powershell
& $env:GODOT_BIN --version
& $env:GODOT_BIN --headless --path . --import
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd
& $env:GODOT_BIN --headless --path . --quit-after 5
git diff --check
git status -sb
```

Expected:

- Godot reports version 4.x.
- Five test files pass with zero failures.
- Headless project smoke test exits with code 0.
- `git diff --check` prints nothing.
- Only intended milestone files are modified before the final commit.

- [ ] **Step 3: Commit the runbook**

```powershell
git add README.md
git commit -m "docs: add Windows Godot runbook"
```

## Plan Self-Review

- The plan covers deterministic starter generation, an owned home star, origin-destination selection, optional surveying, ETA, timed travel, range rejection, pause, 3D rendering, save/resume, and Windows operation.
- Colonization, workforce, territorial links, Zodíaco geometry, combat, and LLM calls remain separate milestones, matching the approved incremental strategy.
- All production methods introduced in Tasks 2 through 7 have a failing test before implementation.
- Configuration and test infrastructure in Task 1 contain no production behavior and are validated by Godot import plus an empty headless suite.
- Method signatures used by presentation and persistence match the interfaces defined in preceding tasks.
