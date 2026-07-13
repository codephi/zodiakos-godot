# Stellar System Composition and Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lazily produce deterministic stars, planets, moons and minor bodies for procedural systems while returning exactly the SQLite records for catalog systems.

**Architecture:** A shared `StellarSystemComposition` domain model represents both sources. `LoadSystemComposition` routes catalog IDs to the repository and procedural IDs to a pure factory. `DynamicNamingService` owns all Zodiakos designations, keeping generated names out of SQLite.

**Tech Stack:** Godot 4.7, GDScript, catalog and galaxy foundations from Plans 1 and 2, native Windows PowerShell tests.

## Global Constraints

- Complete the scientific catalog and finite catalog-aware galaxy plans first.
- Never invoke procedural composition for a catalog system.
- Never insert procedural systems or bodies into SQLite.
- Catalog designations and aliases remain unchanged.
- Procedural designations use galactocentric coordinates and deterministic ordinals.
- Stars use uppercase letters, planets lowercase letters beginning at `b`, moons Roman numerals and minor bodies typed ordinals.
- Put every adjustable generation value in central game settings.
- Keep domain code free from SQLite, Nodes and presentation classes.
- Keep handwritten files below 1,000 lines; use TDD; commit and push after each task.

---

## File Structure

```text
scripts/domain/universe/system_body_definition.gd
scripts/domain/universe/orbit_definition.gd
scripts/domain/universe/stellar_system_composition.gd
scripts/domain/universe/dynamic_naming_service.gd
scripts/domain/universe/procedural_system_factory.gd
scripts/application/universe/load_system_composition.gd
scripts/application/ports/scientific_catalog_repository.gd
scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd
```

### Task 1: Configure procedural composition limits

**Files:**
- Modify: `scripts/config/game_settings.gd`
- Modify carefully: `config/game_settings.tres`
- Modify: `tests/config/test_game_settings.gd`

**Interfaces:**
- Produces exact limits and weighted types for `ProceduralSystemFactory`.

- [ ] **Step 1: Add failing settings assertions**

```gdscript
assert_equal(Settings.system_min_stars, 1, "minimum stars")
assert_equal(Settings.system_max_stars, 3, "maximum stars")
assert_equal(Settings.system_max_planets, 12, "planet cap")
assert_equal(Settings.system_max_moons_per_planet, 4, "moon cap")
assert_equal(Settings.system_max_minor_bodies, 8, "minor body cap")
assert_equal(Settings.system_planet_types, [&"rocky", &"gas", &"ice", &"volcanic"], "planet types")
assert_equal(Settings.system_planet_type_weights, [45, 20, 25, 10], "planet weights")
```

Expected: missing-property failures.

- [ ] **Step 2: Add typed fields and validation**

```gdscript
@export_category("Procedural System Composition")
@export var system_min_stars: int
@export var system_max_stars: int
@export var system_max_planets: int
@export var system_max_moons_per_planet: int
@export var system_max_minor_bodies: int
@export var system_planet_types: Array[StringName]
@export var system_planet_type_weights: Array[int]
```

Validate `1 <= min <= max`, nonnegative body caps, matching nonempty type/weight arrays, known planet visual types and positive weights.

- [ ] **Step 3: Add only these values to the resource**

```text
system_min_stars = 1
system_max_stars = 3
system_max_planets = 12
system_max_moons_per_planet = 4
system_max_minor_bodies = 8
system_planet_types = [&"rocky", &"gas", &"ice", &"volcanic"]
system_planet_type_weights = [45, 20, 25, 10]
```

- [ ] **Step 4: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/config/test_game_settings.gd'
git add scripts/config/game_settings.gd config/game_settings.tres tests/config/test_game_settings.gd
git commit -m "feat: configure procedural system composition"
git push
```

### Task 2: Define shared composition and orbit records

**Files:**
- Create: `scripts/domain/universe/system_body_definition.gd`
- Create: `scripts/domain/universe/orbit_definition.gd`
- Create: `scripts/domain/universe/stellar_system_composition.gd`
- Create: `tests/domain/universe/test_system_composition.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `SystemBodyDefinition` fields `id`, `kind`, `designation`, `proper_name`, `subtype`, `parent_id`, `properties`.
- Produces `OrbitDefinition` fields matching the SQLite `orbits` table.
- Produces immutable arrays `stars`, `planets`, `moons`, `minor_bodies`, `orbits`.

- [ ] **Step 1: Write the failing immutability test**

```gdscript
var star = Body.new(&"proc:test:A", &"star", "ZDK A", "", &"yellow", &"", {})
var bodies := [star]
var composition = Composition.new(&"proc:test", bodies, [], [], [], [])
bodies.clear()
assert_equal(composition.stars.size(), 1, "constructor copies arrays")
var exposed = composition.stars
exposed.clear()
assert_equal(composition.stars.size(), 1, "getter copies arrays")
```

Expected: missing preloads.

- [ ] **Step 2: Implement the records**

Each constructor copies dictionaries with `duplicate(true)` and each composition getter returns `duplicate()`. `kind` accepts `star`, `planet`, `moon` or `minor_body`. `parent_id` is empty only for a system's primary stellar component.

`OrbitDefinition` stores nullable scientific fields in a `properties` dictionary so unknown values remain absent rather than becoming zero.

- [ ] **Step 3: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_system_composition.gd'
git add scripts/domain/universe/system_body_definition.gd scripts/domain/universe/orbit_definition.gd scripts/domain/universe/stellar_system_composition.gd tests/domain/universe/test_system_composition.gd tests/test_runner.gd
git commit -m "feat: define stellar system composition records"
git push
```

### Task 3: Implement deterministic Zodiakos designations

**Files:**
- Create: `scripts/domain/universe/dynamic_naming_service.gd`
- Create: `tests/domain/universe/test_dynamic_naming_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `system_designation(global_position, ordinal)`.
- Produces: `star_designation(system, index)`, `planet_designation(system, index)`, `moon_designation(planet, index)`, `minor_body_designation(system, type, index)`.

- [ ] **Step 1: Write exact naming tests**

```gdscript
assert_equal(naming.system_designation(Vector2(8150.2, 120.4), 3), "ZDK-GX+008150-GY+000120-03", "positive coordinates")
assert_equal(naming.system_designation(Vector2(-12.6, -8.2), 1), "ZDK-GX-000013-GY-000008-01", "negative coordinates")
assert_equal(naming.star_designation("ZDK-X", 0), "ZDK-X A", "first star")
assert_equal(naming.planet_designation("ZDK-X", 0), "ZDK-X b", "first planet")
assert_equal(naming.moon_designation("ZDK-X b", 1), "ZDK-X b-II", "second moon")
assert_equal(naming.minor_body_designation("ZDK-X", &"asteroid", 0), "ZDK-X SB-001", "asteroid")
assert_equal(naming.minor_body_designation("ZDK-X", &"comet", 0), "ZDK-X C-001", "comet")
```

- [ ] **Step 2: Implement formatting without locale dependence**

```gdscript
class_name DynamicNamingService
extends RefCounted

const MINOR_CODES := {&"asteroid": "SB", &"comet": "C", &"dwarf_planet": "DP", &"trans_neptunian": "TNO", &"meteoroid": "M", &"interstellar_object": "I"}
func system_designation(position: Vector2, ordinal: int) -> String:
	return "ZDK-GX%s-GY%s-%02d" % [_coordinate(roundi(position.x)), _coordinate(roundi(position.y)), ordinal]
func star_designation(system: String, index: int) -> String:
	return "%s %s" % [system, String.chr("A".unicode_at(0) + index)]
func planet_designation(system: String, index: int) -> String:
	return "%s %s" % [system, String.chr("b".unicode_at(0) + index)]
func moon_designation(planet: String, index: int) -> String:
	return "%s-%s" % [planet, _roman(index + 1)]
func minor_body_designation(system: String, type: StringName, index: int) -> String:
	return "%s %s-%03d" % [system, MINOR_CODES[type], index + 1]
func _coordinate(value: int) -> String:
	return "%s%06d" % ["+" if value >= 0 else "-", absi(value)]
func _roman(value: int) -> String:
	const VALUES := [10, 9, 5, 4, 1]
	const SYMBOLS := ["X", "IX", "V", "IV", "I"]
	var remaining := value
	var result := ""
	for index in VALUES.size():
		while remaining >= VALUES[index]:
			result += SYMBOLS[index]
			remaining -= VALUES[index]
	return result
```

- [ ] **Step 3: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_dynamic_naming_service.gd'
git add scripts/domain/universe/dynamic_naming_service.gd tests/domain/universe/test_dynamic_naming_service.gd tests/test_runner.gd
git commit -m "feat: generate deterministic system designations"
git push
```

### Task 4: Generate procedural system composition

**Files:**
- Create: `scripts/domain/universe/procedural_system_factory.gd`
- Create: `tests/domain/universe/test_procedural_system_factory.gd`
- Modify: `scripts/domain/universe/seed_mixer.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `create(StellarSystemDefinition, UniverseIdentity) -> StellarSystemComposition`.
- Consumes: `DynamicNamingService` and central settings.

- [ ] **Step 1: Write determinism and structure tests**

Assert the same system and identity produce identical signatures; a different identity changes the signature; counts respect every configured cap; IDs are unique; planets orbit a star or system; moons orbit a generated planet; minor bodies use recognized types; all names match the naming service.

- [ ] **Step 2: Add a seed mixer for arbitrary text**

```gdscript
static func mix_text(seed: int, text: String) -> int:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%d|%s" % [seed, text]).to_utf8_buffer())
	var digest := context.finish()
	var result := 0
	for index in range(7): result = (result << 8) | int(digest[index])
	return result
```

- [ ] **Step 3: Implement the pure factory**

Create one RNG per decision using `mix_text(identity.value, system.id + tag)`. Generate:

- `1..system_max_stars` stars with components `A..C` and weighted existing visual types.
- `0..system_max_planets` planets with weighted configured types and monotonically increasing semi-major axes.
- `0..system_max_moons_per_planet` moons for each planet.
- `0..system_max_minor_bodies` bodies cycling deterministically through supported minor types.

IDs append `:star:<index>`, `:planet:<index>`, `:moon:<planet-index>:<moon-index>` and `:minor:<index>` to the system ID. Every orbit stores its primary body ID. Do not use current time, discovery state or global RNG.

- [ ] **Step 4: Run focused and full tests, then commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/domain/universe/test_procedural_system_factory.gd'
./tools/run_godot_tests.ps1
git add scripts/domain/universe/procedural_system_factory.gd scripts/domain/universe/seed_mixer.gd tests/domain/universe/test_procedural_system_factory.gd tests/test_runner.gd
git commit -m "feat: generate procedural stellar systems"
git push
```

### Task 5: Load complete catalog systems from SQLite

**Files:**
- Modify: `scripts/application/ports/scientific_catalog_repository.gd`
- Modify: `scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd`
- Modify: `tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd`

**Interfaces:**
- Adds: `system_composition(system_id: StringName) -> StellarSystemComposition`.
- Consumes: all subtype tables plus `orbits`.

- [ ] **Step 1: Add a catalog composition test**

Load `catalog:sol` and assert every returned body ID exists in SQLite, Earth has no invented planet letter, Moon's parent is Earth, Ceres is a minor body, and no ID starts with `proc:`. Assert an unknown system returns `null`.

- [ ] **Step 2: Extend the port with an inert method**

```gdscript
func system_composition(_system_id: StringName):
	return null
```

- [ ] **Step 3: Map SQLite rows into the shared model**

Use bound `system_id = ?` queries for stars, planets, moons, minor bodies and orbits. Preserve `canonical_designation`, `proper_name`, subtype and nullable properties. Sort each body array by ID. Never call the procedural naming service in this adapter.

If any query fails, return `null` and preserve the SQLite error for the caller; do not return a partial composition.

- [ ] **Step 4: Run and commit**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
git add scripts/application/ports/scientific_catalog_repository.gd scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd
git commit -m "feat: load catalog system composition"
git push
```

### Task 6: Route catalog and procedural composition without mixing sources

**Files:**
- Create: `scripts/application/universe/load_system_composition.gd`
- Create: `tests/application/universe/test_load_system_composition.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `execute(StellarSystemDefinition) -> StellarSystemComposition`.
- Consumes: repository, procedural factory and universe identity.

- [ ] **Step 1: Write routing tests with spies**

For a definition with `source == catalog`, assert the repository is called exactly once and the factory never runs. For `source == procedural`, assert the factory runs exactly once and the repository never loads composition. Assert a missing catalog composition returns `null` rather than procedural fallback.

- [ ] **Step 2: Implement the use case**

```gdscript
class_name LoadSystemComposition
extends RefCounted
var repository
var factory
var universe_identity
func _init(source_repository, procedural_factory, identity) -> void:
	repository = source_repository
	factory = procedural_factory
	universe_identity = identity
func execute(system_definition):
	if system_definition.source == &"catalog":
		return repository.system_composition(system_definition.id)
	if system_definition.source == &"procedural":
		return factory.create(system_definition, universe_identity)
	return null
```

- [ ] **Step 3: Run focused and full tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/universe/test_load_system_composition.gd'
./tools/run_godot_tests.ps1
```

Expected: pass without stderr.

- [ ] **Step 4: Commit and push**

```powershell
git add scripts/application/universe/load_system_composition.gd tests/application/universe/test_load_system_composition.gd tests/test_runner.gd
git commit -m "feat: load catalog or procedural system composition"
git push
```

## Plan 3 Completion Gate

Run catalog validation, all tests and the Godot smoke check. Verify directly that `catalog:sol` returns only SQLite bodies, two requests for the same procedural ID return identical signatures and names, and the SQLite file hash is unchanged after procedural composition requests.
