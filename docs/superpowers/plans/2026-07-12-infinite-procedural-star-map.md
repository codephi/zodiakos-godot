# Infinite Procedural Star Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, clustered star map that streams forever in every logical direction while keeping Godot rendering close to a floating origin.

**Architecture:** Pure domain objects own 64-bit sector coordinates, local positions, star definitions, and deterministic generation. Godot adapters own the orthographic camera, sector streaming, visual materialization, and debug HUD. The domain never references Nodes, meshes, the SceneTree, input, or wall-clock state.

`UniversePosition` is the first concrete implementation of the architecture's conceptual universe coordinate; `VisibleSectorProjection` and `StarFieldView` are the first slices of `UniverseProjection` and `GodotUniverseView`.

**Tech Stack:** Godot 4.7, GDScript, Compatibility renderer, the existing headless test runner, `RandomNumberGenerator`, `HashingContext`, `Camera3D`, and the existing `StarVisual`.

## Global Constraints

- Develop and validate on native Windows with PowerShell; never use WSL.
- Use TDD for every behavior: failing test, minimal implementation, passing test, refactor.
- Keep every handwritten file below 1,000 lines.
- Use `SectorCoordinate` with two GDScript `int` fields; do not use `Vector2i` for persistent sector identity.
- Store positions as `SectorCoordinate` plus local `Vector2` in `[0, 40)`; never store an unbounded absolute `Vector2`.
- Use seed `0x5A4F4449414B4F53` and generator version `1`.
- Determinism is guaranteed for Godot 4.7 plus generator version 1; an engine or algorithm change requires a generator-version increment.
- The domain must not reference `Node`, `Node3D`, `Camera3D`, `Mesh`, `SceneTree`, or input events.
- Commit and push after every completed task.

## File Map

```text
scripts/domain/universe/sector_coordinate.gd       64-bit sector value object
scripts/domain/universe/universe_position.gd       normalized sector-local position
scripts/domain/universe/seed_mixer.gd              stable derived RNG seeds
scripts/domain/universe/star_definition.gd         immutable generated star data
scripts/domain/universe/universe_sector.gd          immutable generated sector data
scripts/domain/universe/universe_generator_config.gd generation constants
scripts/domain/universe/universe_generator.gd       clustered deterministic generator
scripts/adapters/godot_view/map_camera_controller.gd input and floating camera state
scripts/adapters/godot_view/star_field_view.gd      sector-to-StarVisual materialization
scripts/adapters/godot_view/sector_stream_controller.gd bounded sector lifecycle
scripts/demo/infinite_star_map_demo.gd              runnable composition and HUD
scenes/demo/infinite_star_map_demo.tscn             new main scene
tests/domain/universe/*                              domain tests
tests/adapters/godot_view/*                          adapter tests
tests/demo/test_infinite_star_map_demo.gd            composition test
```

---

### Task 1: 64-bit sector coordinates and normalized positions

**Files:**
- Create: `scripts/domain/universe/sector_coordinate.gd`
- Create: `scripts/domain/universe/universe_position.gd`
- Create: `tests/domain/universe/test_universe_coordinates.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `SectorCoordinate.new(x: int, y: int)`
- Produces: `SectorCoordinate.key() -> String`
- Produces: `SectorCoordinate.offset(delta_x: int, delta_y: int) -> SectorCoordinate`
- Produces: `SectorCoordinate.chebyshev_distance(other: SectorCoordinate) -> int`
- Produces: `UniversePosition.new(sector: SectorCoordinate, local: Vector2)`
- Produces: `UniversePosition.moved(delta: Vector2) -> UniversePosition`
- Produces: `UniversePosition.relative_to(origin: SectorCoordinate) -> Vector2`

- [ ] **Step 1: Write the failing coordinate tests**

```gdscript
# tests/domain/universe/test_universe_coordinates.gd
extends "res://tests/test_case.gd"

const SectorCoordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const UniversePosition = preload("res://scripts/domain/universe/universe_position.gd")

func run() -> void:
	var origin = UniversePosition.new(SectorCoordinate.new(0, 0), Vector2.ZERO)
	var negative = origin.moved(Vector2(-0.1, -0.1))
	assert_equal(negative.sector.key(), "-1:-1", "negative movement changes sector")
	assert_true(negative.local.is_equal_approx(Vector2(39.9, 39.9)), "negative local wraps")
	var edge = origin.moved(Vector2(40.0, 40.0))
	assert_equal(edge.sector.key(), "1:1", "positive edge changes sector")
	assert_equal(edge.local, Vector2.ZERO, "positive edge resets local")
	var huge = SectorCoordinate.new(1 << 40, -(1 << 40))
	assert_equal(huge.key(), "1099511627776:-1099511627776", "coordinate exceeds 32 bits")
	var nearby = UniversePosition.new(huge.offset(2, -1), Vector2(5.0, 7.0))
	assert_equal(nearby.relative_to(huge), Vector2(85.0, -33.0), "relative position stays small")
	assert_equal(huge.chebyshev_distance(huge.offset(-4, 2)), 4, "chebyshev distance")
```

Add `preload("res://tests/domain/universe/test_universe_coordinates.gd")` to `TEST_SCRIPTS`.

- [ ] **Step 2: Run the test and verify RED**

Run: `godot --headless --path . --script res://tests/test_runner.gd --quit-after 5`

Expected: exit nonzero with missing `sector_coordinate.gd` and `universe_position.gd`.

- [ ] **Step 3: Implement `SectorCoordinate`**

```gdscript
# scripts/domain/universe/sector_coordinate.gd
class_name SectorCoordinate
extends RefCounted

var x: int
var y: int

func _init(initial_x := 0, initial_y := 0) -> void:
	x = initial_x
	y = initial_y

func key() -> String:
	return "%d:%d" % [x, y]

func offset(delta_x: int, delta_y: int):
	return get_script().new(x + delta_x, y + delta_y)

func equals(other) -> bool:
	return other != null and x == other.x and y == other.y

func chebyshev_distance(other) -> int:
	return maxi(absi(x - other.x), absi(y - other.y))
```

- [ ] **Step 4: Implement `UniversePosition`**

```gdscript
# scripts/domain/universe/universe_position.gd
class_name UniversePosition
extends RefCounted

const SectorCoordinateType = preload("res://scripts/domain/universe/sector_coordinate.gd")
const SECTOR_SIZE := 40.0
var sector
var local: Vector2

func _init(initial_sector = null, initial_local := Vector2.ZERO) -> void:
	sector = initial_sector if initial_sector != null else SectorCoordinateType.new()
	local = initial_local
	_normalize()

func moved(delta: Vector2):
	return get_script().new(sector.offset(0, 0), local + delta)

func relative_to(origin) -> Vector2:
	return Vector2(float(sector.x - origin.x), float(sector.y - origin.y)) * SECTOR_SIZE + local

func _normalize() -> void:
	var delta_x := int(floor(local.x / SECTOR_SIZE))
	var delta_y := int(floor(local.y / SECTOR_SIZE))
	sector = sector.offset(delta_x, delta_y)
	local -= Vector2(delta_x, delta_y) * SECTOR_SIZE
```

- [ ] **Step 5: Run GREEN, inspect, commit, and push**

Run: `godot --headless --path . --script res://tests/test_runner.gd --quit-after 5`

Expected: `TESTS PASSED`, exit 0, no stderr.

Commit: `feat: add infinite universe coordinates`

---

### Task 2: Stable generated data and seed derivation

**Files:**
- Create: `scripts/domain/universe/seed_mixer.gd`
- Create: `scripts/domain/universe/star_definition.gd`
- Create: `scripts/domain/universe/universe_sector.gd`
- Create: `scripts/domain/universe/universe_generator_config.gd`
- Create: `tests/domain/universe/test_generation_foundations.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `SectorCoordinate` from Task 1.
- Produces: `SeedMixer.mix(global_seed: int, coordinate: SectorCoordinate, tag: String, first_index := -1, second_index := -1) -> int`
- Produces: `StarDefinition.new(id, sector, local_position, visual_type, source, owner_sector, priority)`
- Produces: `UniverseSector.new(coordinate, stars)`
- Produces: all constants on `UniverseGeneratorConfig`.

- [ ] **Step 1: Write failing foundation tests**

```gdscript
# tests/domain/universe/test_generation_foundations.gd
extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Star = preload("res://scripts/domain/universe/star_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")

func run() -> void:
	var coordinate = Coordinate.new(-7, 9)
	var first = Mixer.mix(Config.GLOBAL_SEED, coordinate, "cluster", 1, 2)
	var second = Mixer.mix(Config.GLOBAL_SEED, coordinate, "cluster", 1, 2)
	assert_equal(first, second, "derived seed is stable")
	assert_true(first >= 0, "derived seed is nonnegative")
	assert_true(first != Mixer.mix(Config.GLOBAL_SEED, coordinate, "isolated", 1, 2), "tag changes seed")
	var star = Star.new(&"b", coordinate, Vector2(2, 3), &"yellow", &"cluster", coordinate, 10)
	var star_a = Star.new(&"a", coordinate, Vector2(1, 1), &"red", &"isolated", coordinate, 9)
	var sector = Sector.new(coordinate, [star, star_a])
	assert_equal(sector.stars[0].id, &"a", "sector sorts stars by id")
	var leaked_copy := sector.stars; leaked_copy.clear()
	assert_equal(sector.stars.size(), 2, "sector does not expose mutable star array")
	assert_equal(Config.SECTOR_SIZE, 40.0, "sector size")
	assert_equal(Config.GENERATOR_VERSION, 1, "generator version")
```

- [ ] **Step 2: Run RED**

Run the complete test runner. Expected: missing generation foundation scripts.

- [ ] **Step 3: Implement deterministic seed mixing**

```gdscript
# scripts/domain/universe/seed_mixer.gd
class_name SeedMixer
extends RefCounted

static func mix(global_seed: int, coordinate, tag: String, first_index := -1, second_index := -1) -> int:
	var input := "%d|%d|%d|%s|%d|%d" % [global_seed, coordinate.x, coordinate.y, tag, first_index, second_index]
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(input.to_utf8_buffer())
	var digest := context.finish()
	var result := 0
	for index in range(7):
		result = (result << 8) | int(digest[index])
	return result
```

- [ ] **Step 4: Implement the data objects and constants**

```gdscript
# scripts/domain/universe/universe_generator_config.gd
class_name UniverseGeneratorConfig
extends RefCounted
const GLOBAL_SEED := 0x5A4F4449414B4F53
const GENERATOR_VERSION := 1
const SECTOR_SIZE := 40.0
const MIN_CLUSTERS := 0
const MAX_CLUSTERS := 2
const MIN_CLUSTER_STARS := 8
const MAX_CLUSTER_STARS := 20
const MIN_CLUSTER_RADIUS := 8.0
const MAX_CLUSTER_RADIUS := 18.0
const MAX_ISOLATED_STARS := 3
const MINIMUM_DISTANCE := 1.5
const MAX_STARS_PER_SECTOR := 64
const VISUAL_TYPES := [&"yellow", &"red", &"white", &"orange", &"blue"]
```

```gdscript
# scripts/domain/universe/star_definition.gd
class_name StarDefinition
extends RefCounted
var id: StringName: get: return _id
var sector: get: return _sector.offset(0, 0)
var local_position: Vector2: get: return _local_position
var visual_type: StringName: get: return _visual_type
var source: StringName: get: return _source
var owner_sector: get: return _owner_sector.offset(0, 0)
var priority: int: get: return _priority
var generator_version: int: get: return 1
var _id: StringName; var _sector; var _local_position: Vector2
var _visual_type: StringName; var _source: StringName; var _owner_sector; var _priority: int

func _init(star_id, star_sector, position: Vector2, type, star_source, owner, star_priority: int) -> void:
	_id = star_id; _sector = star_sector.offset(0, 0); _local_position = position
	_visual_type = type; _source = star_source; _owner_sector = owner.offset(0, 0); _priority = star_priority
```

```gdscript
# scripts/domain/universe/universe_sector.gd
class_name UniverseSector
extends RefCounted
var coordinate: get: return _coordinate.offset(0, 0)
var stars: Array: get: return _stars.duplicate()
var generator_version: int: get: return 1
var _coordinate; var _stars: Array

func _init(sector_coordinate, generated_stars: Array) -> void:
	_coordinate = sector_coordinate.offset(0, 0)
	_stars = generated_stars.duplicate()
	_stars.sort_custom(func(left, right): return String(left.id) < String(right.id))
```

- [ ] **Step 5: Run GREEN, commit, and push**

Expected: complete runner prints `TESTS PASSED` with no errors.

Commit: `feat: add procedural generation foundations`

---

### Task 3: Clustered deterministic universe generator

**Files:**
- Create: `scripts/domain/universe/universe_generator.gd`
- Create: `tests/domain/universe/test_universe_generator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: every domain interface from Tasks 1 and 2.
- Produces: `UniverseGenerator.new(global_seed := UniverseGeneratorConfig.GLOBAL_SEED)`
- Produces: `UniverseGenerator.generate_sector(coordinate: SectorCoordinate) -> UniverseSector`

- [ ] **Step 1: Write failing generator tests**

```gdscript
# tests/domain/universe/test_universe_generator.gd
extends "res://tests/test_case.gd"

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")

func run() -> void:
	var generator = Generator.new()
	var coordinate = Coordinate.new(-2, 3)
	var first = generator.generate_sector(coordinate)
	var second = generator.generate_sector(coordinate)
	assert_equal(_signature(first), _signature(second), "same request is deterministic")
	var reversed = Generator.new()
	reversed.generate_sector(Coordinate.new(8, -5))
	assert_equal(_signature(first), _signature(reversed.generate_sector(coordinate)), "request order is irrelevant")
	assert_true(_signature(first) != _signature(Generator.new(Config.GLOBAL_SEED + 1).generate_sector(coordinate)), "seed changes stars")
	_assert_region_rules(generator, Coordinate.new(0, 0))

func _signature(sector) -> Array:
	var result := []
	for star in sector.stars:
		result.append([String(star.id), star.local_position, String(star.visual_type), star.priority])
	return result

func _assert_region_rules(generator, center) -> void:
	var all_stars := []
	var ids := {}
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var sector = generator.generate_sector(center.offset(offset_x, offset_y))
			assert_true(sector.stars.size() <= Config.MAX_STARS_PER_SECTOR, "sector cap")
			for star in sector.stars:
				assert_true(not ids.has(star.id), "star id is unique")
				ids[star.id] = true
				assert_true(Config.VISUAL_TYPES.has(star.visual_type), "known visual type")
				all_stars.append(star)
	for index in all_stars.size():
		for other_index in range(index + 1, all_stars.size()):
			var left = all_stars[index]
			var right = all_stars[other_index]
			var delta_sector = Vector2(left.sector.x - right.sector.x, left.sector.y - right.sector.y)
			var delta = delta_sector * Config.SECTOR_SIZE + left.local_position - right.local_position
			assert_true(delta.length() >= Config.MINIMUM_DISTANCE - 0.001, "global minimum distance")
```

- [ ] **Step 2: Run RED**

Expected: missing `universe_generator.gd`.

- [ ] **Step 3: Implement candidate generation**

```gdscript
# scripts/domain/universe/universe_generator.gd
class_name UniverseGenerator
extends RefCounted

const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Mixer = preload("res://scripts/domain/universe/seed_mixer.gd")
const Star = preload("res://scripts/domain/universe/star_definition.gd")
const Sector = preload("res://scripts/domain/universe/universe_sector.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")

class Candidate:
	var id: StringName; var position: Vector2; var visual_type: StringName
	var source: StringName; var owner; var priority: int

var global_seed: int

func _init(seed := Config.GLOBAL_SEED) -> void:
	global_seed = seed

func generate_sector(target) -> RefCounted:
	var candidates := _generate_nearby_candidates(target)
	var accepted := []
	for candidate in candidates:
		if _is_local_winner(candidate, candidates): accepted.append(candidate)
	accepted.sort_custom(func(left, right):
		return left.priority < right.priority if left.priority != right.priority else String(left.id) < String(right.id))
	var stars := []
	for candidate in accepted:
		if _inside_target(candidate.position):
			stars.append(Star.new(candidate.id, target.offset(0, 0), candidate.position, candidate.visual_type, candidate.source, candidate.owner, candidate.priority))
			if stars.size() == Config.MAX_STARS_PER_SECTOR: break
	return Sector.new(target.offset(0, 0), stars)

func _generate_nearby_candidates(target) -> Array:
	var result := []
	for owner_y in range(-1, 2):
		for owner_x in range(-1, 2):
			var owner = target.offset(owner_x, owner_y)
			_append_clusters(result, owner, Vector2(owner_x, owner_y) * Config.SECTOR_SIZE)
			_append_isolated(result, owner, Vector2(owner_x, owner_y) * Config.SECTOR_SIZE)
	return result.filter(func(candidate):
		return candidate.position.x >= -Config.MINIMUM_DISTANCE and candidate.position.y >= -Config.MINIMUM_DISTANCE and candidate.position.x < Config.SECTOR_SIZE + Config.MINIMUM_DISTANCE and candidate.position.y < Config.SECTOR_SIZE + Config.MINIMUM_DISTANCE)

func _append_clusters(result: Array, owner, owner_origin: Vector2) -> void:
	var cluster_count := _rng(owner, "cluster_count").randi_range(Config.MIN_CLUSTERS, Config.MAX_CLUSTERS)
	for cluster_index in cluster_count:
		var parameters := _indexed_rng(owner, "cluster_parameters", cluster_index)
		var center := owner_origin + Vector2(parameters.randf_range(0.0, Config.SECTOR_SIZE), parameters.randf_range(0.0, Config.SECTOR_SIZE))
		var radius := parameters.randf_range(Config.MIN_CLUSTER_RADIUS, Config.MAX_CLUSTER_RADIUS)
		var axis_ratio := parameters.randf_range(0.65, 1.0)
		var ellipse_rotation := parameters.randf_range(0.0, TAU)
		var star_count := parameters.randi_range(Config.MIN_CLUSTER_STARS, Config.MAX_CLUSTER_STARS)
		for star_index in star_count:
			var star_rng := _indexed_rng(owner, "cluster_star", cluster_index, star_index)
			var distance := radius * pow(star_rng.randf(), 1.8)
			var point := Vector2.from_angle(star_rng.randf_range(0.0, TAU)) * Vector2(distance, distance * axis_ratio)
			_append_candidate(result, owner, center + point.rotated(ellipse_rotation), &"cluster", cluster_index, star_index)

func _append_isolated(result: Array, owner, owner_origin: Vector2) -> void:
	var count := _rng(owner, "isolated_count").randi_range(0, Config.MAX_ISOLATED_STARS)
	for star_index in count:
		var star_rng := _indexed_rng(owner, "isolated_star", star_index)
		var point := owner_origin + Vector2(star_rng.randf_range(0.0, Config.SECTOR_SIZE), star_rng.randf_range(0.0, Config.SECTOR_SIZE))
		_append_candidate(result, owner, point, &"isolated", -1, star_index)
```

- [ ] **Step 4: Implement candidate identity, types, and distance resolution**

Append to `universe_generator.gd`:

```gdscript
func _append_candidate(result: Array, owner, position: Vector2, source: StringName, cluster_index: int, star_index: int) -> void:
	var prefix := "cluster:%d:%d:%d:%d" % [owner.x, owner.y, cluster_index, star_index] if source == &"cluster" else "isolated:%d:%d:%d" % [owner.x, owner.y, star_index]
	var candidate := Candidate.new()
	candidate.id = StringName(prefix); candidate.position = position; candidate.source = source
	candidate.owner = owner.offset(0, 0)
	candidate.priority = Mixer.mix(global_seed, owner, prefix)
	candidate.visual_type = _visual_type(owner, prefix)
	result.append(candidate)

func _visual_type(owner, identity: String) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, "type:" + identity)
	var roll := rng.randi_range(0, 99)
	if roll < 35: return &"yellow"
	if roll < 60: return &"red"
	if roll < 80: return &"white"
	if roll < 95: return &"orange"
	return &"blue"

func _rng(owner, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, tag)
	return rng

func _indexed_rng(owner, tag: String, first := -1, second := -1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Mixer.mix(global_seed, owner, tag, first, second)
	return rng

func _is_local_winner(candidate, candidates: Array) -> bool:
	var minimum_squared := Config.MINIMUM_DISTANCE * Config.MINIMUM_DISTANCE
	for other in candidates:
		if other == candidate or candidate.position.distance_squared_to(other.position) >= minimum_squared: continue
		if other.priority < candidate.priority or (other.priority == candidate.priority and String(other.id) < String(candidate.id)): return false
	return true

func _inside_target(position: Vector2) -> bool:
	return position.x >= 0.0 and position.y >= 0.0 and position.x < Config.SECTOR_SIZE and position.y < Config.SECTOR_SIZE
```

- [ ] **Step 5: Run GREEN and repeat the region test for negative and distant coordinates**

Add calls for centers `(-3, -4)` and `((1 << 40), -(1 << 40))` to `_assert_region_rules`. Run the complete suite and expect exit 0 with no errors.

- [ ] **Step 6: Commit and push**

Commit: `feat: generate deterministic clustered stars`

---

### Task 4: Orthographic map camera with floating logical position

**Files:**
- Create: `scripts/adapters/godot_view/map_camera_controller.gd`
- Create: `tests/adapters/godot_view/test_map_camera_controller.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `UniversePosition` and `SectorCoordinate`.
- Produces: `MapCameraController.apply_drag_pixels(delta: Vector2, viewport_height: float)`
- Produces: `MapCameraController.apply_zoom_steps(steps: int)`
- Produces signals: `logical_position_changed(position)` and `zoom_changed(size: float)`.

- [ ] **Step 1: Write failing camera tests**

```gdscript
# tests/adapters/godot_view/test_map_camera_controller.gd
extends "res://tests/test_case.gd"
const CameraController = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")

func run() -> void:
	var camera = CameraController.new()
	var height := camera.position.y
	camera.begin_drag(); camera.accumulate_drag_pixels(Vector2(2, 0), 1000.0)
	assert_equal(camera.logical_position.local, Vector2.ZERO, "motion below four pixels remains a click")
	camera.accumulate_drag_pixels(Vector2(98, 50), 1000.0); camera.end_drag()
	assert_true(camera.logical_position.local != Vector2.ZERO, "drag moves logical position")
	assert_equal(camera.position.y, height, "drag preserves camera height")
	camera.apply_zoom_steps(100)
	assert_equal(camera.size, camera.MINIMUM_SIZE, "zoom in clamps")
	camera.apply_zoom_steps(-200)
	assert_equal(camera.size, camera.MAXIMUM_SIZE, "zoom out clamps")
	camera.logical_position = camera.logical_position.moved(Vector2(-100, -100))
	camera.sync_visual_position()
	assert_true(absf(camera.position.x) <= 40.0 and absf(camera.position.z) <= 40.0, "camera remains near floating origin")
	camera.free()
```

- [ ] **Step 2: Run RED**

Expected: missing camera controller script.

- [ ] **Step 3: Implement the camera controller**

```gdscript
# scripts/adapters/godot_view/map_camera_controller.gd
class_name MapCameraController
extends Camera3D
signal logical_position_changed(position)
signal zoom_changed(new_size: float)
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const MINIMUM_SIZE := 20.0
const MAXIMUM_SIZE := 90.0
const ZOOM_FACTOR := 0.88
const CAMERA_HEIGHT := 40.0
var logical_position = PositionType.new(Coordinate.new(), Vector2.ZERO)
var dragging := false
var drag_active := false
var drag_accumulator := Vector2.ZERO

func _init() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL; size = 50.0; rotation_degrees.x = -90.0
	position = Vector3(0.0, CAMERA_HEIGHT, 0.0); current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: begin_drag()
		else: end_drag()
	elif event is InputEventMouseMotion and dragging: accumulate_drag_pixels(event.relative, get_viewport().get_visible_rect().size.y)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: apply_zoom_steps(1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: apply_zoom_steps(-1)

func begin_drag() -> void:
	dragging = true; drag_active = false; drag_accumulator = Vector2.ZERO
func end_drag() -> void:
	dragging = false; drag_active = false; drag_accumulator = Vector2.ZERO
func accumulate_drag_pixels(delta: Vector2, viewport_height: float) -> void:
	drag_accumulator += delta
	if not drag_active and drag_accumulator.length() < 4.0: return
	drag_active = true; apply_drag_pixels(drag_accumulator, viewport_height); drag_accumulator = Vector2.ZERO

func apply_drag_pixels(delta: Vector2, viewport_height: float) -> void:
	if viewport_height <= 0.0: return
	logical_position = logical_position.moved(-delta * (size / viewport_height))
	sync_visual_position(); logical_position_changed.emit(logical_position)

func apply_zoom_steps(steps: int) -> void:
	if steps > 0:
		for index in steps: size *= ZOOM_FACTOR
	else:
		for index in -steps: size /= ZOOM_FACTOR
	size = clampf(size, MINIMUM_SIZE, MAXIMUM_SIZE); zoom_changed.emit(size)

func sync_visual_position() -> void:
	position = Vector3(logical_position.local.x, CAMERA_HEIGHT, logical_position.local.y)
```

- [ ] **Step 4: Run GREEN, commit, and push**

Commit: `feat: add infinite map camera controls`

---

### Task 5: Pure visible-sector projection

**Files:**
- Create: `scripts/application/projections/visible_sector_projection.gd`
- Create: `tests/application/projections/test_visible_sector_projection.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `SectorCoordinate`.
- Produces: `VisibleSectorProjection.load_order(center, active_keys, queued_keys) -> Array`
- Produces: `VisibleSectorProjection.unload_coordinates(center, active_coordinates) -> Array`

- [ ] **Step 1: Write the failing projection test**

```gdscript
# tests/application/projections/test_visible_sector_projection.gd
extends "res://tests/test_case.gd"
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const Projection = preload("res://scripts/application/projections/visible_sector_projection.gd")
func run() -> void:
	var projection = Projection.new()
	var center = Coordinate.new(4, -2)
	var order = projection.load_order(center, {}, {})
	assert_equal(order.size(), 25, "load radius contains 25 sectors")
	assert_equal(order[0].key(), center.key(), "center loads first")
	var excluded = {center.key(): true}
	assert_equal(projection.load_order(center, excluded, {}).size(), 24, "active key is excluded")
	var far = [center.offset(4, 0), center.offset(0, -4), center.offset(3, 3)]
	assert_equal(projection.unload_coordinates(center, far).size(), 2, "only distance above three unloads")
```

- [ ] **Step 2: Run RED, then implement the projection**

```gdscript
# scripts/application/projections/visible_sector_projection.gd
class_name VisibleSectorProjection
extends RefCounted
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 3

func load_order(center, active_keys: Dictionary, queued_keys: Dictionary) -> Array:
	var result := []
	for y in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for x in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coordinate = center.offset(x, y); var key := coordinate.key()
			if not active_keys.has(key) and not queued_keys.has(key): result.append(coordinate)
	result.sort_custom(func(left, right):
		var left_distance := left.chebyshev_distance(center); var right_distance := right.chebyshev_distance(center)
		if left_distance != right_distance: return left_distance < right_distance
		if left.y != right.y: return left.y < right.y
		return left.x < right.x)
	return result

func unload_coordinates(center, active_coordinates: Array) -> Array:
	return active_coordinates.filter(func(coordinate): return coordinate.chebyshev_distance(center) > UNLOAD_RADIUS)
```

Run the complete suite; expect `TESTS PASSED`. Commit and push as `feat: project visible star sectors`.

---

### Task 6: Bounded sector streaming and star materialization

**Files:**
- Create: `scripts/adapters/godot_view/star_field_view.gd`
- Create: `scripts/adapters/godot_view/sector_stream_controller.gd`
- Modify: `scripts/visuals/star_visual.gd`
- Create: `tests/adapters/godot_view/test_sector_streaming.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `UniverseGenerator.generate_sector`, `UniversePosition`, `VisibleSectorProjection`, and `StarVisual.configure`.
- Produces: `StarFieldView.materialize_sector(sector, render_origin)`
- Produces: `StarFieldView.remove_sector(coordinate)`
- Produces: `StarFieldView.rebase(render_origin)`
- Produces: `StarFieldView.active_sector_count() -> int`
- Produces: `StarFieldView.star_count() -> int`
- Produces: `SectorStreamController.configure(generator, view, initial_position)`
- Produces: `SectorStreamController.update_center(position)`
- Produces: `SectorStreamController.process_pending(limit := 2)`

- [ ] **Step 1: Write failing streaming tests**

```gdscript
# tests/adapters/godot_view/test_sector_streaming.gd
extends "res://tests/test_case.gd"
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Coordinate = preload("res://scripts/domain/universe/sector_coordinate.gd")
const PositionType = preload("res://scripts/domain/universe/universe_position.gd")
const View = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const Controller = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const StarVisualType = preload("res://scripts/visuals/star_visual.gd")

func run() -> void:
	var view = View.new(); var controller = Controller.new(); var generator = Generator.new()
	controller.configure(generator, view, PositionType.new(Coordinate.new(), Vector2.ZERO))
	controller.process_pending(2)
	assert_equal(view.active_sector_count(), 2, "batch loads at most two sectors")
	controller.process_pending(100)
	assert_equal(view.active_sector_count(), 25, "load radius creates 25 sectors")
	assert_true(view.star_count() > 0, "stars are materialized")
	var original_signature = view.sector_signature(Coordinate.new())
	controller.update_center(PositionType.new(Coordinate.new(10, 0), Vector2.ZERO)); controller.process_pending(100)
	assert_true(view.active_sector_count() <= 49, "active sectors stay bounded")
	assert_true(not view.has_sector(Coordinate.new()), "distant origin unloads")
	controller.update_center(PositionType.new(Coordinate.new(), Vector2.ZERO)); controller.process_pending(100)
	assert_equal(view.sector_signature(Coordinate.new()), original_signature, "return rematerializes same stars")
	var first_visual = StarVisualType.new(); var second_visual = StarVisualType.new()
	first_visual.configure(&"yellow"); second_visual.configure(&"yellow")
	assert_true(first_visual.get_node("Body").mesh == second_visual.get_node("Body").mesh, "stars share mesh")
	assert_true(not first_visual.get_node("OwnerRing").visible, "neutral star skips owner ring")
	first_visual.free(); second_visual.free()
	controller.free(); view.free()
```

- [ ] **Step 2: Run RED**

Expected: missing view and stream controller.

- [ ] **Step 3: Reuse star resources and skip neutral rings**

Add these fields and replace `configure` in `StarVisual`:

```gdscript
static var shared_sphere: SphereMesh
static var materials_by_type := {}

func configure(star_type: StringName, owner_color := Color(0, 0, 0, 0), selected := false) -> void:
	var style := Palette.star_style(star_type)
	if shared_sphere == null:
		shared_sphere = SphereMesh.new(); shared_sphere.radial_segments = 16; shared_sphere.rings = 8
	if not materials_by_type.has(star_type):
		materials_by_type[star_type] = Materials.create(style.color, true, false, true)
	body.mesh = shared_sphere; body.material_override = materials_by_type[star_type]
	scale = Vector3.ONE * float(style.scale)
	var show_ring := owner_color.a > 0.0 or selected
	if show_ring: owner_ring.configure(Palette.normalize_owner_color(owner_color), 0.82 if selected else 0.75, true)
	else: owner_ring.visible = false
```

- [ ] **Step 4: Implement `StarFieldView`**

```gdscript
# scripts/adapters/godot_view/star_field_view.gd
class_name StarFieldView
extends Node3D
const StarVisualType = preload("res://scripts/visuals/star_visual.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")
var active := {}
var render_origin

func materialize_sector(sector, origin) -> void:
	render_origin = origin
	if active.has(sector.coordinate.key()): return
	var container := Node3D.new(); container.name = "Sector_%d_%d" % [sector.coordinate.x, sector.coordinate.y]
	add_child(container)
	for definition in sector.stars:
		var visual := StarVisualType.new(); visual.name = String(definition.id); visual.set_meta("star_id", definition.id)
		visual.position = Vector3(definition.local_position.x, 0.0, definition.local_position.y)
		container.add_child(visual); visual.configure(definition.visual_type)
	active[sector.coordinate.key()] = {"coordinate": sector.coordinate, "sector": sector, "node": container}
	_reposition(active[sector.coordinate.key()])

func rebase(origin) -> void:
	render_origin = origin
	for entry in active.values(): _reposition(entry)

func _reposition(entry: Dictionary) -> void:
	var coordinate = entry.coordinate
	entry.node.position = Vector3(float(coordinate.x - render_origin.x) * Config.SECTOR_SIZE, 0.0, float(coordinate.y - render_origin.y) * Config.SECTOR_SIZE)

func remove_sector(coordinate) -> void:
	var entry = active.get(coordinate.key())
	if entry == null: return
	entry.node.queue_free(); active.erase(coordinate.key())

func has_sector(coordinate) -> bool: return active.has(coordinate.key())
func active_keys() -> Dictionary:
	var result := {}
	for key in active: result[key] = true
	return result
func active_coordinates() -> Array:
	var result := []
	for entry in active.values(): result.append(entry.coordinate)
	return result
func active_sector_count() -> int: return active.size()
func star_count() -> int:
	var total := 0
	for entry in active.values(): total += entry.sector.stars.size()
	return total
func sector_signature(coordinate) -> Array:
	var result := []
	for star in active[coordinate.key()].sector.stars: result.append(String(star.id))
	return result
```

- [ ] **Step 5: Implement `SectorStreamController`**

```gdscript
# scripts/adapters/godot_view/sector_stream_controller.gd
class_name SectorStreamController
extends Node
signal stats_changed(active_sectors: int, visible_stars: int, center_key: String)
const Projection = preload("res://scripts/application/projections/visible_sector_projection.gd")
var generator; var view; var center; var pending := []; var queued := {}; var projection = Projection.new()

func configure(source_generator, target_view, initial_position) -> void:
	generator = source_generator; view = target_view; update_center(initial_position)

func update_center(position) -> void:
	center = position.sector.offset(0, 0); view.rebase(center)
	pending.clear(); queued.clear()
	for coordinate in projection.load_order(center, view.active_keys(), queued):
		pending.append(coordinate); queued[coordinate.key()] = true
	for coordinate in projection.unload_coordinates(center, view.active_coordinates()): view.remove_sector(coordinate)
	_emit_stats()

func _process(_delta: float) -> void: process_pending(2)
func process_pending(limit := 2) -> void:
	for index in mini(limit, pending.size()):
		var coordinate = pending.pop_front(); queued.erase(coordinate.key())
		view.materialize_sector(generator.generate_sector(coordinate), center)
	_emit_stats()
func _emit_stats() -> void:
	if center != null: stats_changed.emit(view.active_sector_count(), view.star_count(), center.key())
```

- [ ] **Step 6: Run GREEN, commit, and push**

Run the complete suite. Expected: `TESTS PASSED`, active sectors bounded, no errors.

Commit: `feat: stream procedural star sectors`

---

### Task 7: Infinite map scene, HUD, and main entry point

**Files:**
- Create: `scripts/demo/infinite_star_map_demo.gd`
- Create: `scenes/demo/infinite_star_map_demo.tscn`
- Create: `tests/demo/test_infinite_star_map_demo.gd`
- Modify: `tests/test_runner.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: camera, generator, projection, view, and streaming interfaces from Tasks 3–6.
- Produces: runnable `res://scenes/demo/infinite_star_map_demo.tscn`.

- [ ] **Step 1: Write the failing composition test**

```gdscript
# tests/demo/test_infinite_star_map_demo.gd
extends "res://tests/test_case.gd"
const Demo = preload("res://scenes/demo/infinite_star_map_demo.tscn")
func run() -> void:
	var demo = Demo.instantiate()
	assert_true(demo.get_node_or_null("MapCamera") != null, "map camera exists")
	assert_true(demo.get_node_or_null("SectorStreamController") != null, "stream controller exists")
	assert_true(demo.get_node_or_null("SectorRoot") != null, "sector root exists")
	assert_true(demo.get_node_or_null("DebugHud/Stats") != null, "debug HUD exists")
	demo.get_node("SectorStreamController").process_pending(100)
	assert_equal(demo.get_node("SectorRoot").active_sector_count(), 25, "initial sectors load")
	demo.free()
```

- [ ] **Step 2: Run RED**

Expected: missing infinite map scene.

- [ ] **Step 3: Implement the demo composition**

```gdscript
# scripts/demo/infinite_star_map_demo.gd
extends Node3D
const CameraType = preload("res://scripts/adapters/godot_view/map_camera_controller.gd")
const ViewType = preload("res://scripts/adapters/godot_view/star_field_view.gd")
const StreamType = preload("res://scripts/adapters/godot_view/sector_stream_controller.gd")
const Generator = preload("res://scripts/domain/universe/universe_generator.gd")
const Config = preload("res://scripts/domain/universe/universe_generator_config.gd")
var stats_label: Label
var camera; var sector_view; var stream

func _init() -> void:
	camera = CameraType.new(); camera.name = "MapCamera"; add_child(camera)
	sector_view = ViewType.new(); sector_view.name = "SectorRoot"; add_child(sector_view)
	stream = StreamType.new(); stream.name = "SectorStreamController"; add_child(stream)
	_add_environment(); _add_hud()
	stream.configure(Generator.new(), sector_view, camera.logical_position)
	camera.logical_position_changed.connect(stream.update_center)
	stream.stats_changed.connect(_update_stats)

func _add_environment() -> void:
	var world := WorldEnvironment.new(); world.name = "WorldEnvironment"
	var environment := Environment.new(); environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111f"); environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE; environment.ambient_light_energy = 1.0
	world.environment = environment; add_child(world)

func _add_hud() -> void:
	var layer := CanvasLayer.new(); layer.name = "DebugHud"; add_child(layer)
	stats_label = Label.new(); stats_label.name = "Stats"; stats_label.position = Vector2(16, 16)
	stats_label.text = "Seed: 0x%X" % Config.GLOBAL_SEED; layer.add_child(stats_label)

func _update_stats(sectors: int, stars: int, center_key: String) -> void:
	stats_label.text = "Seed: 0x%X\nSector: %s\nActive: %d\nStars: %d\nZoom: %.1f" % [Config.GLOBAL_SEED, center_key, sectors, stars, camera.size]
```

```ini
# scenes/demo/infinite_star_map_demo.tscn
[gd_scene load_steps=2 format=3]
[ext_resource path="res://scripts/demo/infinite_star_map_demo.gd" type="Script" id="1"]
[node name="InfiniteStarMapDemo" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 4: Make the infinite map the project entry point**

Change `[application]` in `project.godot` to:

```ini
run/main_scene="res://scenes/demo/infinite_star_map_demo.tscn"
```

- [ ] **Step 5: Run automated and smoke checks**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd --quit-after 5
godot --headless --path . --quit-after 5
git diff --check
```

Expected: runner prints `TESTS PASSED`; both Godot processes exit 0 with empty stderr; diff check returns no errors.

- [ ] **Step 6: Validate visibly in the existing Godot editor**

Run the main scene. Drag across at least ten sector widths in positive and negative X and Y, zoom to both limits, return to the origin, and confirm the same star pattern and bounded HUD counts.

- [ ] **Step 7: Commit and push**

Commit: `feat: add infinite procedural star map demo`

---

### Task 8: Final architectural and regression verification

**Files:**
- Modify only files requiring corrections discovered by the checks.

- [ ] **Step 1: Verify domain isolation**

Run:

```powershell
rg -n "extends (Node|Node3D)|Camera3D|Mesh|SceneTree|InputEvent" scripts/domain
```

Expected: no matches.

- [ ] **Step 2: Verify file limits and repository scope**

Run:

```powershell
Get-ChildItem scripts,scenes,tests -Recurse -File | Where-Object { (Get-Content $_.FullName).Count -gt 1000 }
git status -sb
```

Expected: no oversized files and no unrelated changes.

- [ ] **Step 3: Run the full verification suite again**

Run the test runner, main-scene smoke check, and `git diff --check` from Task 7. Expected: all pass with no stderr.

- [ ] **Step 4: Commit corrections only when verification changed files**

Use commit message `fix: finalize infinite procedural map` and push. Do not create an empty commit.
