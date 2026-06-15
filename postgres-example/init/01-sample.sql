-- Loads the sample Denmark POI dataset into a `sample.geospatial_points` table.
-- Runs automatically on first container start (Postgres initdb), against POSTGRES_DB (dekart_geo).

CREATE SCHEMA IF NOT EXISTS sample;

-- Raw load straight from the CSV.
CREATE TABLE sample.geospatial_points_raw (
    name           TEXT,
    latitude       DOUBLE PRECISION,
    longitude      DOUBLE PRECISION,
    basic_category TEXT
);

COPY sample.geospatial_points_raw (name, latitude, longitude, basic_category)
FROM '/docker-entrypoint-initdb.d/denmark-pois.csv'
WITH (FORMAT csv, HEADER true);

-- Tidy table with an id and a WKT geometry string (kepler.gl reads WKT directly).
CREATE TABLE sample.geospatial_points (
    id        SERIAL PRIMARY KEY,
    name      TEXT,
    category  TEXT,
    longitude DOUBLE PRECISION,
    latitude  DOUBLE PRECISION,
    geom_wkt  TEXT
);

INSERT INTO sample.geospatial_points (name, category, longitude, latitude, geom_wkt)
SELECT
    name,
    basic_category,
    longitude,
    latitude,
    'POINT(' || longitude || ' ' || latitude || ')'
FROM sample.geospatial_points_raw;

CREATE INDEX ON sample.geospatial_points (category);

-- German cities (name, state, lat/lon, population) — for the Germany examples.
CREATE TABLE sample.germany_cities (
    name       TEXT,
    state      TEXT,
    latitude   DOUBLE PRECISION,
    longitude  DOUBLE PRECISION,
    population  INTEGER
);

COPY sample.germany_cities (name, state, latitude, longitude, population)
FROM '/docker-entrypoint-initdb.d/germany-cities.csv'
WITH (FORMAT csv, HEADER true);

CREATE INDEX ON sample.germany_cities (state);

-- German intercity corridors as WKT LINESTRINGs.
CREATE TABLE sample.germany_lines (
    name         TEXT,
    from_city    TEXT,
    to_city      TEXT,
    distance_km  DOUBLE PRECISION,
    geom_wkt     TEXT
);

COPY sample.germany_lines (name, from_city, to_city, distance_km, geom_wkt)
FROM '/docker-entrypoint-initdb.d/germany-lines.csv'
WITH (FORMAT csv, HEADER true);

-- Macro-region hulls as WKT POLYGONs (derived from the city points).
CREATE TABLE sample.germany_regions (
    region    TEXT,
    n_cities  INTEGER,
    geom_wkt  TEXT
);

COPY sample.germany_regions (region, n_cities, geom_wkt)
FROM '/docker-entrypoint-initdb.d/germany-regions.csv'
WITH (FORMAT csv, HEADER true);
