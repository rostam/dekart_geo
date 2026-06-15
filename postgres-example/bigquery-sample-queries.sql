-- Sample geospatial queries for Dekart using BigQuery PUBLIC datasets.
-- These read from `bigquery-public-data.*` (free to query; you pay only for
-- bytes scanned in YOUR project). Paste any one into a Dekart map and run.
-- kepler.gl auto-detects latitude/longitude columns, or a WKT/GeoJSON column.

-- 1) NYC Citi Bike stations — points (lat/lon)
SELECT
  name,
  latitude,
  longitude,
  capacity,
  num_bikes_available
FROM `bigquery-public-data.new_york_citibike.citibike_stations`
WHERE latitude IS NOT NULL
LIMIT 2000;


-- 2) Austin bikeshare kiosks — points
SELECT
  name,
  latitude,
  longitude,
  status,
  number_of_docks
FROM `bigquery-public-data.austin_bikeshare.bikeshare_stations`
WHERE latitude IS NOT NULL
LIMIT 2000;


-- 3) Chicago taxi pickups — point cloud (good for heatmaps)
SELECT
  pickup_latitude  AS latitude,
  pickup_longitude AS longitude,
  fare,
  trip_miles
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`
WHERE pickup_latitude IS NOT NULL
  AND trip_start_timestamp >= TIMESTAMP('2022-01-01')
LIMIT 50000;


-- 4) US state boundaries — POLYGONS as WKT
-- Convert the GEOGRAPHY column to WKT text so kepler.gl can render it.
SELECT
  state_name,
  state,
  ST_ASTEXT(state_geom) AS geom_wkt
FROM `bigquery-public-data.geo_us_boundaries.states`;


-- 5) US county boundaries — POLYGONS as WKT, with a value to color by
SELECT
  county_name,
  state_fips_code,
  ST_AREA(county_geom) / 1e6 AS area_km2,
  ST_ASTEXT(county_geom)     AS geom_wkt
FROM `bigquery-public-data.geo_us_boundaries.counties`
LIMIT 5000;


-- 6) OpenStreetMap points of interest near a bounding box (example: Berlin)
SELECT
  osm_id,
  ST_ASTEXT(geometry) AS geom_wkt,
  (SELECT value FROM UNNEST(all_tags) WHERE key = 'amenity') AS amenity,
  (SELECT value FROM UNNEST(all_tags) WHERE key = 'name')    AS name
FROM `bigquery-public-data.geo_openstreetmap.planet_features`
WHERE 'amenity' IN (SELECT key FROM UNNEST(all_tags))
  AND ST_INTERSECTS(
        geometry,
        ST_MAKEPOLYGON(ST_MAKELINE([
          ST_GEOGPOINT(13.30, 52.45), ST_GEOGPOINT(13.50, 52.45),
          ST_GEOGPOINT(13.50, 52.55), ST_GEOGPOINT(13.30, 52.55),
          ST_GEOGPOINT(13.30, 52.45)
        ]))
      )
LIMIT 20000;
