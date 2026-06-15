-- Sample geospatial queries for the LOCAL Postgres data source.
-- Runs against the preloaded `sample.geospatial_points` table
-- (columns: id, name, category, longitude, latitude, geom_wkt).
-- Paste any one into a Dekart map (port 8080) and run.
-- kepler.gl auto-detects the latitude/longitude columns (or geom_wkt).

-- 1) All points (capped) — basic point map, color by category
SELECT id, name, category, latitude, longitude
FROM sample.geospatial_points
LIMIT 5000;


-- 2) One category only — e.g. museums
SELECT name, category, latitude, longitude
FROM sample.geospatial_points
WHERE category = 'museum'
LIMIT 5000;


-- 3) A few related categories (food & drink) — color by category
SELECT name, category, latitude, longitude
FROM sample.geospatial_points
WHERE category IN ('bakery', 'restaurant', 'cafe', 'bar', 'fast_food')
LIMIT 10000;


-- 4) Category counts — useful as a sortable table / bar layer
SELECT category, COUNT(*) AS n
FROM sample.geospatial_points
GROUP BY category
ORDER BY n DESC;


-- 5) Bounding box around Bornholm (where most of the sample sits)
--    lon 14.6–15.2, lat 54.9–55.3 — good for testing zoom/extent
SELECT name, category, latitude, longitude
FROM sample.geospatial_points
WHERE longitude BETWEEN 14.6 AND 15.2
  AND latitude  BETWEEN 54.9 AND 55.3
LIMIT 20000;


-- 6) Per-category centroid (average position) — sized by point count
SELECT
  category,
  COUNT(*)        AS n,
  AVG(latitude)   AS latitude,
  AVG(longitude)  AS longitude
FROM sample.geospatial_points
GROUP BY category
HAVING COUNT(*) > 20
ORDER BY n DESC;


-- 7) WKT points directly (kepler reads the geom_wkt column as geometry)
SELECT name, category, geom_wkt
FROM sample.geospatial_points
LIMIT 5000;


-- ===========================================================================
-- GERMANY — sample.germany_cities (name, state, latitude, longitude, population)
-- ===========================================================================

-- G1) All German cities, size/color by population
SELECT name, state, latitude, longitude, population
FROM sample.germany_cities
ORDER BY population DESC;

-- G2) Big cities only (> 500k)
SELECT name, state, latitude, longitude, population
FROM sample.germany_cities
WHERE population > 500000
ORDER BY population DESC;

-- G3) Cities in one state (e.g. North Rhine-Westphalia)
SELECT name, latitude, longitude, population
FROM sample.germany_cities
WHERE state = 'North Rhine-Westphalia'
ORDER BY population DESC;

-- G4) Population aggregated by state — centroid + total (bubble map)
SELECT state,
       COUNT(*)        AS cities,
       SUM(population)  AS population,
       AVG(latitude)   AS latitude,
       AVG(longitude)  AS longitude
FROM sample.germany_cities
GROUP BY state
ORDER BY population DESC;

-- G5) Cities around Berlin (bounding box)
SELECT name, latitude, longitude, population
FROM sample.germany_cities
WHERE longitude BETWEEN 12.0 AND 14.5
  AND latitude  BETWEEN 51.5 AND 53.5;

-- G6) LINES — intercity corridors (run in a NEW map). The `geometry` column is
--     GeoJSON, which kepler.gl auto-detects and draws as a path layer.
SELECT name, from_city, to_city, distance_km, geometry
FROM sample.germany_lines
ORDER BY distance_km DESC;

-- G7) POLYGONS — macro-region hulls (run in a NEW map). Color by n_cities.
SELECT region, n_cities, geometry
FROM sample.germany_regions;

-- G8) Long corridors only (> 300 km)
SELECT name, distance_km, geometry
FROM sample.germany_lines
WHERE distance_km > 300;

-- Note: `geom_wkt` (WKT text) is also available in both tables for use in an
-- external SQL client; kepler renders the GeoJSON `geometry` column more reliably.

-- G9) ALL GEOMETRIES TOGETHER — points + lines + polygons in ONE GeoJSON layer.
--     City lat/lon is converted to a GeoJSON Point so everything shares one
--     `geometry` column. Color the layer by `kind` (point/line/polygon).
SELECT 'point'   AS kind, name   AS label, population::double precision AS value,
       json_build_object('type', 'Point',
         'coordinates', json_build_array(longitude, latitude))::text    AS geometry
FROM sample.germany_cities
UNION ALL
SELECT 'line'    AS kind, name   AS label, distance_km                  AS value, geometry
FROM sample.germany_lines
UNION ALL
SELECT 'polygon' AS kind, region AS label, n_cities::double precision   AS value, geometry
FROM sample.germany_regions;

-- Tip: you can also show them together by adding THREE separate queries to one
-- map (G1 points, G6 lines, G7 polygons) — each becomes its own layer you can
-- style independently. G9 is the single-query / single-layer version.


-- ---------------------------------------------------------------------------
-- OPTIONAL: polygons/hulls need PostGIS. To enable, switch the compose `pg`
-- image to `postgis/postgis:16-3.4`, add `CREATE EXTENSION IF NOT EXISTS
-- postgis;` to init/01-sample.sql, then `docker compose down -v && up -d`.
-- Then queries like this work (convex hull per category as WKT polygons):
--
--   SELECT category,
--          COUNT(*) AS n,
--          ST_AsText(ST_ConvexHull(ST_Collect(
--            ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)))) AS geom_wkt
--   FROM sample.geospatial_points
--   GROUP BY category
--   HAVING COUNT(*) > 50;
-- ---------------------------------------------------------------------------
