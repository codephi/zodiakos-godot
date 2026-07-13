# Scientific SQLite Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a validated, read-only SQLite scientific catalog containing the initial Solar System and expose spatial system anchors through a hexagonal repository port.

**Architecture:** The domain defines catalog records and a repository port. A Godot-SQLite adapter owns all SQL and returns immutable domain records. The production SQLite file is the only catalog data source; the checked-in SQL file records schema history only.

**Tech Stack:** Godot 4.7, GDScript, Godot-SQLite v4.7 with SQLite 3.51.0, native Windows PowerShell, existing custom Godot test runner.

## Global Constraints

- Develop and validate on native Windows with PowerShell; do not use WSL.
- Pin Godot-SQLite to release `v4.7` and verify the published SHA-256 before installation.
- Open `res://data/catalog/zodiakos_catalog.sqlite` with `read_only = true` and `foreign_keys = true` at runtime.
- SQLite is the only source of catalog data; do not add CSV or JSON mirrors.
- Keep domain and application code independent from `SQLite`, Node, SceneTree, meshes and UI.
- Preserve uncommitted edits in `config/game_settings.tres` and `project.godot`; stage only files named by each task.
- Keep every handwritten file below 1,000 lines.
- Use TDD and commit and push after every completed task.

## Observed Baseline

On 2026-07-13, `camera_max_zoom` contains the user's uncommitted value `30000.0`, while existing configuration and camera tests still expect `300.0`. The demo suite also times out because its old maximum-zoom test asks streaming to enumerate the complete `30000.0` viewport. Plan 1 does not change or stage those files and therefore uses only the catalog-related focused suites. Plan 2 deliberately synchronizes the stale assertions while preserving `30000.0`.

---

## File Structure

```text
addons/godot-sqlite/                         Vendored pinned GDExtension
data/catalog/schema/001_initial.sql          Schema history only
data/catalog/zodiakos_catalog.sqlite         Single production catalog source
scripts/domain/catalog/catalog_metadata.gd   Version value object
scripts/domain/catalog/system_anchor.gd      Catalog system used by map generation
scripts/application/ports/scientific_catalog_repository.gd
scripts/application/catalog/catalog_validation_result.gd
scripts/application/catalog/catalog_validator.gd
scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd
tests/dependencies/test_sqlite_dependency.gd
tests/fixtures/sqlite_catalog_fixture.gd
tests/application/catalog/test_catalog_validator.gd
tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd
tools/install_godot_sqlite.ps1
tools/catalog/validate_catalog.gd
```

### Task 1: Pin and verify Godot-SQLite

**Files:**
- Create: `tools/install_godot_sqlite.ps1`
- Create: `tests/dependencies/test_sqlite_dependency.gd`
- Modify: `tests/test_runner.gd`
- Vendor: `addons/godot-sqlite/**`

**Interfaces:**
- Produces: globally registered GDExtension class `SQLite`.
- Consumes: Godot-SQLite `v4.7` release asset `demo.zip`.

- [ ] **Step 1: Add the dependency test and register it**

```gdscript
# tests/dependencies/test_sqlite_dependency.gd
extends "res://tests/test_case.gd"


func run() -> void:
	assert_true(ClassDB.class_exists(&"SQLite"), "SQLite GDExtension is registered")
```

Add its preload as the first entry in `TEST_SCRIPTS`:

```gdscript
preload("res://tests/dependencies/test_sqlite_dependency.gd"),
```

- [ ] **Step 2: Run the test to verify it fails before installation**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/dependencies/test_sqlite_dependency.gd'
```

Expected: failure stating `SQLite GDExtension is registered` is false.

- [ ] **Step 3: Create the reproducible installer**

```powershell
# tools/install_godot_sqlite.ps1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$url = 'https://github.com/2shady4u/godot-sqlite/releases/download/v4.7/demo.zip'
$expected = '26966044757cf86a223a8027f8bc88c49c289ab047dcf8138bb591d7632e580e'
$temporary = Join-Path $env:TEMP ("godot-sqlite-v4.7-{0}" -f [guid]::NewGuid())
$archive = "$temporary.zip"

try {
    Invoke-WebRequest -Uri $url -OutFile $archive
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "Godot-SQLite checksum mismatch: $actual"
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $temporary
    $extension = Get-ChildItem -Path $temporary -Recurse -Filter gdsqlite.gdextension |
        Select-Object -First 1
    if ($null -eq $extension) {
        throw 'gdsqlite.gdextension was not present in the release archive.'
    }
    $source = $extension.Directory.FullName
    $destination = Join-Path $root 'addons\godot-sqlite'
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
} finally {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 4: Install and rerun the focused test**

Run:

```powershell
./tools/install_godot_sqlite.ps1
./tools/run_godot_tests.ps1 -Suite 'res://tests/dependencies/test_sqlite_dependency.gd'
```

Expected: `TESTS PASSED` and `GODOT TEST WRAPPER PASSED`.

- [ ] **Step 5: Commit and push**

```powershell
git add addons/godot-sqlite tools/install_godot_sqlite.ps1 tests/dependencies/test_sqlite_dependency.gd tests/test_runner.gd
git commit -m "build: pin Godot SQLite dependency"
git push
```

### Task 2: Create the relational schema and direct SQLite catalog

**Files:**
- Create: `data/catalog/schema/001_initial.sql`
- Create: `data/catalog/zodiakos_catalog.sqlite`
- Test: `data/catalog/zodiakos_catalog.sqlite`

**Interfaces:**
- Produces: schema version `1`, catalog version `1`, coordinate model version `1`.
- Consumes: `sqlite3` CLI available through native Windows `PATH`.

- [ ] **Step 1: Write the initial schema**

Create `001_initial.sql` with `PRAGMA foreign_keys = ON;`, the ten tables from the approved spec, `CHECK` constraints for object kinds and minor-body types, and these exact required constraints:

```sql
BEGIN;
CREATE TABLE catalog_metadata (
    schema_version INTEGER NOT NULL CHECK (schema_version > 0),
    catalog_version INTEGER NOT NULL CHECK (catalog_version > 0),
    catalog_name TEXT NOT NULL,
    coordinate_model_version INTEGER NOT NULL CHECK (coordinate_model_version > 0),
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL
);
CREATE TABLE catalog_objects (
    id TEXT PRIMARY KEY CHECK (id LIKE 'catalog:%'),
    object_kind TEXT NOT NULL CHECK (object_kind IN ('stellar_system','star','planet','moon','minor_body')),
    canonical_designation TEXT NOT NULL,
    proper_name TEXT,
    discovery_year INTEGER,
    notes TEXT,
    UNIQUE (object_kind, canonical_designation)
);
CREATE TABLE stellar_systems (
    object_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    ra_deg REAL,
    dec_deg REAL,
    distance_pc REAL CHECK (distance_pc IS NULL OR distance_pc >= 0),
    coordinate_epoch TEXT,
    galactocentric_x_pc REAL NOT NULL,
    galactocentric_y_pc REAL NOT NULL,
    galactocentric_z_pc REAL NOT NULL,
    system_class TEXT
);
CREATE TABLE stars (
    object_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    system_id TEXT NOT NULL REFERENCES stellar_systems(object_id),
    component TEXT NOT NULL,
    spectral_type TEXT,
    mass_solar REAL CHECK (mass_solar IS NULL OR mass_solar >= 0),
    radius_solar REAL CHECK (radius_solar IS NULL OR radius_solar >= 0),
    temperature_k REAL CHECK (temperature_k IS NULL OR temperature_k >= 0),
    luminosity_solar REAL CHECK (luminosity_solar IS NULL OR luminosity_solar >= 0),
    UNIQUE (system_id, component)
);
CREATE TABLE planets (
    object_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    system_id TEXT NOT NULL REFERENCES stellar_systems(object_id),
    planet_letter TEXT,
    planet_class TEXT,
    mass_earth REAL CHECK (mass_earth IS NULL OR mass_earth >= 0),
    radius_earth REAL CHECK (radius_earth IS NULL OR radius_earth >= 0),
    equilibrium_temperature_k REAL CHECK (equilibrium_temperature_k IS NULL OR equilibrium_temperature_k >= 0),
    UNIQUE (system_id, planet_letter)
);
CREATE TABLE moons (
    object_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    system_id TEXT NOT NULL REFERENCES stellar_systems(object_id),
    planet_id TEXT NOT NULL REFERENCES planets(object_id),
    satellite_designation TEXT,
    mass_kg REAL CHECK (mass_kg IS NULL OR mass_kg >= 0),
    radius_km REAL CHECK (radius_km IS NULL OR radius_km >= 0)
);
CREATE TABLE minor_bodies (
    object_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    system_id TEXT NOT NULL REFERENCES stellar_systems(object_id),
    minor_body_type TEXT NOT NULL CHECK (minor_body_type IN ('asteroid','comet','dwarf_planet','trans_neptunian','meteoroid','interstellar_object')),
    orbit_class TEXT,
    mass_kg REAL CHECK (mass_kg IS NULL OR mass_kg >= 0),
    radius_km REAL CHECK (radius_km IS NULL OR radius_km >= 0),
    albedo REAL CHECK (albedo IS NULL OR (albedo >= 0 AND albedo <= 1))
);
CREATE TABLE orbits (
    orbiter_id TEXT PRIMARY KEY REFERENCES catalog_objects(id),
    primary_object_id TEXT NOT NULL REFERENCES catalog_objects(id),
    semi_major_axis_au REAL CHECK (semi_major_axis_au IS NULL OR semi_major_axis_au >= 0),
    eccentricity REAL CHECK (eccentricity IS NULL OR eccentricity >= 0),
    inclination_deg REAL,
    orbital_period_days REAL CHECK (orbital_period_days IS NULL OR orbital_period_days >= 0),
    longitude_ascending_node_deg REAL,
    argument_periapsis_deg REAL,
    mean_anomaly_deg REAL,
    elements_epoch TEXT,
    CHECK (orbiter_id <> primary_object_id)
);
CREATE TABLE aliases (
    id INTEGER PRIMARY KEY,
    object_id TEXT NOT NULL REFERENCES catalog_objects(id),
    catalog_name TEXT NOT NULL,
    alias TEXT NOT NULL,
    UNIQUE (catalog_name, alias)
);
CREATE TABLE sources (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    authors TEXT,
    publication_year INTEGER,
    doi TEXT,
    url TEXT,
    accessed_at_utc TEXT
);
CREATE TABLE object_sources (
    object_id TEXT NOT NULL REFERENCES catalog_objects(id),
    source_id TEXT NOT NULL REFERENCES sources(id),
    source_role TEXT NOT NULL CHECK (source_role IN ('position','orbit','physical','nomenclature')),
    PRIMARY KEY (object_id, source_id, source_role)
);
CREATE INDEX idx_system_x ON stellar_systems(galactocentric_x_pc);
CREATE INDEX idx_system_y ON stellar_systems(galactocentric_y_pc);
CREATE INDEX idx_stars_system ON stars(system_id);
CREATE INDEX idx_planets_system ON planets(system_id);
CREATE INDEX idx_moons_system_planet ON moons(system_id, planet_id);
CREATE INDEX idx_minor_bodies_system ON minor_bodies(system_id);
CREATE INDEX idx_aliases_object ON aliases(object_id);
CREATE INDEX idx_object_sources_object ON object_sources(object_id);
COMMIT;
```

- [ ] **Step 2: Create the database from the schema**

Run from the repository root:

```powershell
New-Item -ItemType Directory -Path data/catalog -Force | Out-Null
sqlite3 data/catalog/zodiakos_catalog.sqlite ".read data/catalog/schema/001_initial.sql"
sqlite3 data/catalog/zodiakos_catalog.sqlite "INSERT INTO catalog_metadata VALUES (1,1,'Zodiakos Scientific Catalog',1,'2026-07-13T00:00:00Z','2026-07-13T00:00:00Z');"
```

- [ ] **Step 3: Verify schema integrity**

Run:

```powershell
sqlite3 data/catalog/zodiakos_catalog.sqlite "PRAGMA integrity_check; PRAGMA foreign_key_check; SELECT schema_version,catalog_version,coordinate_model_version FROM catalog_metadata;"
```

Expected output contains `ok` and `1|1|1`, with no foreign-key rows.

- [ ] **Step 4: Commit and push**

```powershell
git add data/catalog/schema/001_initial.sql data/catalog/zodiakos_catalog.sqlite
git commit -m "feat: add scientific catalog schema"
git push
```

### Task 3: Define catalog domain records and repository port

**Files:**
- Create: `scripts/domain/catalog/catalog_metadata.gd`
- Create: `scripts/domain/catalog/system_anchor.gd`
- Create: `scripts/application/ports/scientific_catalog_repository.gd`
- Create: `tests/application/catalog/test_catalog_contracts.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `CatalogMetadata.new(schema_version, catalog_version, coordinate_model_version)`.
- Produces: `SystemAnchor.new(id, designation, proper_name, Vector3)`.
- Produces port methods `open()`, `close()`, `metadata()`, `systems_in_bounds(Rect2)`, `technical_validation_errors()`.

- [ ] **Step 1: Write the failing contract test**

```gdscript
extends "res://tests/test_case.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")
const Repository = preload("res://scripts/application/ports/scientific_catalog_repository.gd")


func run() -> void:
	var metadata = Metadata.new(1, 2, 3)
	assert_equal(metadata.catalog_version, 2, "catalog version is exposed")
	var anchor = Anchor.new(&"catalog:sol", "Sol", "Sun", Vector3(8150.0, 0.0, 20.8))
	assert_equal(anchor.map_position(), Vector2(8150.0, 0.0), "anchor maps x and y")
	assert_true(Repository.new().systems_in_bounds(Rect2()).is_empty(), "base port is inert")
```

Register the suite and run it. Expected: preload failure because the three files do not exist.

- [ ] **Step 2: Implement immutable records and inert port**

```gdscript
# catalog_metadata.gd
class_name CatalogMetadata
extends RefCounted
var schema_version: int
var catalog_version: int
var coordinate_model_version: int
func _init(schema: int, catalog: int, coordinates: int) -> void:
	schema_version = schema
	catalog_version = catalog
	coordinate_model_version = coordinates
```

```gdscript
# system_anchor.gd
class_name SystemAnchor
extends RefCounted
var id: StringName
var canonical_designation: String
var proper_name: String
var galactocentric_position: Vector3
func _init(anchor_id: StringName, designation: String, name: String, position: Vector3) -> void:
	id = anchor_id
	canonical_designation = designation
	proper_name = name
	galactocentric_position = position
func map_position() -> Vector2:
	return Vector2(galactocentric_position.x, galactocentric_position.y)
```

```gdscript
# scientific_catalog_repository.gd
class_name ScientificCatalogRepository
extends RefCounted
func open() -> bool: return false
func close() -> void: pass
func metadata(): return null
func systems_in_bounds(_bounds: Rect2) -> Array: return []
func technical_validation_errors() -> PackedStringArray: return PackedStringArray()
```

- [ ] **Step 3: Run the suite**

Run:

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_contracts.gd'
```

Expected: pass.

- [ ] **Step 4: Commit and push**

```powershell
git add scripts/domain/catalog scripts/application/ports tests/application/catalog/test_catalog_contracts.gd tests/test_runner.gd
git commit -m "feat: define scientific catalog contracts"
git push
```

### Task 4: Implement the read-only SQLite repository

**Files:**
- Create: `scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd`
- Create: `tests/fixtures/sqlite_catalog_fixture.gd`
- Create: `tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `SQLite.new()`, `query_with_bindings(sql, values)` and `query_result`.
- Produces: concrete implementation of `ScientificCatalogRepository`.

- [ ] **Step 1: Build a disposable fixture and failing adapter test**

The fixture copies the production database to `user://catalog_repository_test.sqlite`, opens it writable, inserts `catalog:fixture`, then closes it. The test opens that copy through the adapter, requests `Rect2(8100,-50,100,100)`, and asserts the fixture anchor is returned. It also asserts `database.read_only` is true through an adapter inspection method restricted to tests.

```gdscript
var repository = SqliteRepository.new(fixture.path)
assert_true(repository.open(), "repository opens fixture")
assert_equal(repository.metadata().schema_version, 1, "schema version")
var anchors = repository.systems_in_bounds(Rect2(8100.0, -50.0, 100.0, 100.0))
assert_equal(anchors.size(), 1, "bounded query returns fixture")
assert_equal(anchors[0].id, &"catalog:fixture", "anchor mapping")
repository.close()
fixture.cleanup()
```

Run the suite. Expected: preload failure for the missing adapter.

- [ ] **Step 2: Implement the adapter with bound parameters**

```gdscript
class_name SqliteScientificCatalogRepository
extends "res://scripts/application/ports/scientific_catalog_repository.gd"

const Metadata = preload("res://scripts/domain/catalog/catalog_metadata.gd")
const Anchor = preload("res://scripts/domain/catalog/system_anchor.gd")

var database_path: String
var database

func _init(path := "res://data/catalog/zodiakos_catalog.sqlite") -> void:
	database_path = path

func open() -> bool:
	database = SQLite.new()
	database.path = database_path
	database.read_only = true
	database.foreign_keys = true
	database.verbosity_level = 0
	return database.open_db()

func close() -> void:
	if database != null:
		database.close_db()
		database = null

func metadata():
	if not database.query("SELECT schema_version,catalog_version,coordinate_model_version FROM catalog_metadata"):
		return null
	if database.query_result.size() != 1:
		return null
	var row: Dictionary = database.query_result[0]
	return Metadata.new(row.schema_version, row.catalog_version, row.coordinate_model_version)

func systems_in_bounds(bounds: Rect2) -> Array:
	const SQL := "SELECT o.id,o.canonical_designation,COALESCE(o.proper_name,'') AS proper_name,s.galactocentric_x_pc,s.galactocentric_y_pc,s.galactocentric_z_pc FROM stellar_systems s JOIN catalog_objects o ON o.id=s.object_id WHERE s.galactocentric_x_pc>=? AND s.galactocentric_x_pc<? AND s.galactocentric_y_pc>=? AND s.galactocentric_y_pc<? ORDER BY o.id"
	var values := [bounds.position.x, bounds.end.x, bounds.position.y, bounds.end.y]
	if not database.query_with_bindings(SQL, values):
		return []
	var result := []
	for row in database.query_result:
		result.append(Anchor.new(StringName(row.id), row.canonical_designation, row.proper_name, Vector3(row.galactocentric_x_pc, row.galactocentric_y_pc, row.galactocentric_z_pc)))
	return result

func is_read_only_for_tests() -> bool:
	return database != null and database.read_only
```

Add `technical_validation_errors()` in Task 5; until then it returns `PackedStringArray()`.

- [ ] **Step 3: Run adapter and catalog contract tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_contracts.gd'
```

Expected: both pass without stderr.

- [ ] **Step 4: Commit and push**

```powershell
git add scripts/adapters/persistence/sqlite tests/fixtures/sqlite_catalog_fixture.gd tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd tests/test_runner.gd
git commit -m "feat: read scientific systems from SQLite"
git push
```

### Task 5: Validate technical and relational integrity

**Files:**
- Create: `scripts/application/catalog/catalog_validation_result.gd`
- Create: `scripts/application/catalog/catalog_validator.gd`
- Create: `tests/application/catalog/test_catalog_validator.gd`
- Modify: `scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `CatalogValidator.validate(repository) -> CatalogValidationResult`.
- Produces: stable error codes such as `CATALOG_NOT_OPEN`, `SCHEMA_UNSUPPORTED`, `SQLITE_INTEGRITY`, `FOREIGN_KEY`, `SUBTYPE_MISMATCH`, `ORBIT_CYCLE`.

- [ ] **Step 1: Write tests for valid, missing-metadata and broken-relation fixtures**

Use three fixture copies. Assert the valid copy has no errors, deleting metadata yields `METADATA_COUNT`, and disabling foreign keys before inserting an invalid moon yields `FOREIGN_KEY` after reopening.

```gdscript
var result = Validator.new().validate(repository)
assert_true(result.is_valid(), "valid catalog passes")
assert_true(not broken_result.is_valid(), "broken catalog fails")
assert_true(broken_result.codes().has(&"FOREIGN_KEY"), "foreign key failure is explicit")
```

Run the suite. Expected: missing validator preload.

- [ ] **Step 2: Add adapter technical checks**

Implement queries for:

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;
SELECT COUNT(*) AS count FROM catalog_metadata;
SELECT o.id FROM catalog_objects o LEFT JOIN stellar_systems s ON o.id=s.object_id WHERE o.object_kind='stellar_system' AND s.object_id IS NULL;
WITH RECURSIVE path(origin,current) AS (SELECT orbiter_id,primary_object_id FROM orbits UNION ALL SELECT path.origin,o.primary_object_id FROM path JOIN orbits o ON o.orbiter_id=path.current) SELECT DISTINCT origin FROM path WHERE origin=current;
```

Return stable code/message dictionaries from `technical_validation_errors()`; never print or swallow the SQLite error.

Add explicit queries for all remaining invariants: each `catalog_objects.object_kind` has exactly one matching subtype; no subtype has the wrong kind; moon and planet belong to the same system; every orbital primary belongs to the orbiter's system or is that system's catalog object; all galactocentric coordinates satisfy `value = value` and `abs(value) < 1.0e9`; and no normalized canonical designation is duplicated. Map failures to `SUBTYPE_MISMATCH`, `CROSS_SYSTEM_PARENT`, `NON_FINITE_COORDINATE` and `DUPLICATE_DESIGNATION`.

- [ ] **Step 3: Implement application validation**

`CatalogValidator` requires exactly one metadata row, supports schema `1`, and copies the adapter's technical errors into `CatalogValidationResult`. `CatalogValidationResult` exposes `add(code, message)`, `is_valid()`, `codes()` and `messages()`.

- [ ] **Step 4: Run focused catalog tests**

```powershell
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_validator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
```

Expected: pass without stderr.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/application/catalog scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd tests/application/catalog/test_catalog_validator.gd tests/test_runner.gd
git commit -m "feat: validate scientific catalog integrity"
git push
```

### Task 6: Curate the initial Solar System directly in SQLite

**Files:**
- Modify directly: `data/catalog/zodiakos_catalog.sqlite`
- Create: `tests/adapters/persistence/test_production_catalog.gd`
- Modify: `tests/test_runner.gd`
- Create: `tools/catalog/validate_catalog.gd`

**Interfaces:**
- Produces catalog IDs: `catalog:sol`, `catalog:sun`, all eight major planets, `catalog:moon`, `catalog:1-ceres`, `catalog:1p-halley`.
- Produces anchor position for Sol: `Vector3(8150.0, 0.0, 20.8)` parsecs in coordinate model `1`.

- [ ] **Step 1: Write the production catalog test**

Open the production database, validate it, query around `(8150,0)`, and assert exactly one `catalog:sol` anchor. Query the database through a test-only repository method `count_objects_by_kind()` and assert one star, eight planets, at least one moon and two minor bodies.

- [ ] **Step 2: Insert curated rows in one direct transaction**

Use the `sqlite3` interactive shell or a trusted SQLite editor. Do not check in an INSERT seed file. Insert this exact baseline identity and relationship set; physical and orbital measurements are copied from the linked source, while a value absent from that source remains `NULL`:

| ID | Kind/subtype | Canonical designation | Orbital primary |
| --- | --- | --- | --- |
| `catalog:sol` | stellar system | Solar System | none |
| `catalog:sun` | star/G2V | Sun | none |
| `catalog:mercury` | planet/rocky | Mercury | `catalog:sun` |
| `catalog:venus` | planet/rocky | Venus | `catalog:sun` |
| `catalog:earth` | planet/rocky | Earth | `catalog:sun` |
| `catalog:mars` | planet/rocky | Mars | `catalog:sun` |
| `catalog:jupiter` | planet/gas | Jupiter | `catalog:sun` |
| `catalog:saturn` | planet/gas | Saturn | `catalog:sun` |
| `catalog:uranus` | planet/ice | Uranus | `catalog:sun` |
| `catalog:neptune` | planet/ice | Neptune | `catalog:sun` |
| `catalog:moon` | moon | Moon | `catalog:earth` |
| `catalog:1-ceres` | minor body/dwarf planet | (1) Ceres | `catalog:sun` |
| `catalog:1p-halley` | minor body/comet | 1P/Halley | `catalog:sun` |

All planets have `planet_letter = NULL`. Use `https://science.nasa.gov/solar-system/` for planetary physical/orbital values, `https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1` for Ceres, `https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=1P` for Halley, and the coordinate-model sources already cited in the design spec for Sol's galactocentric position. Record those URLs in `sources` and connect each object through `object_sources`.

Finish with:

```sql
UPDATE catalog_metadata
SET catalog_version = 2,
    updated_at_utc = '2026-07-13T00:00:00Z';
COMMIT;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

The exact values entered must be copied from the cited NASA, IAU or MPC source and linked in `sources`; unknown values remain `NULL`.

- [ ] **Step 3: Add the headless validation entry point**

```gdscript
extends SceneTree
const Repository = preload("res://scripts/adapters/persistence/sqlite/sqlite_scientific_catalog_repository.gd")
const Validator = preload("res://scripts/application/catalog/catalog_validator.gd")
func _initialize() -> void:
	var repository = Repository.new()
	if not repository.open():
		push_error("CATALOG_NOT_OPEN")
		quit(1)
		return
	var result = Validator.new().validate(repository)
	repository.close()
	if not result.is_valid():
		push_error("CATALOG_INVALID: %s" % "; ".join(result.messages()))
		quit(1)
		return
	print("CATALOG VALID")
	print("TESTS PASSED")
	quit(0)
```

- [ ] **Step 4: Verify the production file and all tests**

```powershell
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/dependencies/test_sqlite_dependency.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_contracts.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_validator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_production_catalog.gd'
```

Expected: `CATALOG VALID`, then `TESTS PASSED`, with no stderr.

- [ ] **Step 5: Commit and push**

```powershell
git add data/catalog/zodiakos_catalog.sqlite tools/catalog/validate_catalog.gd tests/adapters/persistence/test_production_catalog.gd tests/test_runner.gd
git commit -m "data: add initial scientific Solar System catalog"
git push
```

## Plan 1 Completion Gate

Run:

```powershell
./tools/run_godot_tests.ps1 -RunnerScript 'res://tools/catalog/validate_catalog.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/dependencies/test_sqlite_dependency.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_contracts.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/application/catalog/test_catalog_validator.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_sqlite_scientific_catalog_repository.gd'
./tools/run_godot_tests.ps1 -Suite 'res://tests/adapters/persistence/test_production_catalog.gd'
git status --short --branch
```

Expected: catalog validation and all tests pass. Only the user's pre-existing `config/game_settings.tres` and `project.godot` edits may remain unstaged.
