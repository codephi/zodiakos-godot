PRAGMA foreign_keys = ON;

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
