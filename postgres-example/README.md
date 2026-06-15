# Dekart local example — Postgres data source + sample maps

A self-contained, fully-local [Dekart](https://dekart.xyz) playground:

- **Postgres** preloaded with sample geo data (Denmark POIs + German cities,
  intercity lines, and region polygons), wired up as a Dekart **data source**.
- **MinIO** (local S3) for query-result storage — no cloud, no license key.
- **Dekart** on http://localhost:8080.
- Optional **BigQuery** instance and a **patched image** that can load style files.

Everything is driven by one script: **`./dekart.sh`**.

## Quick start

```sh
cd postgres-example
./dekart.sh up                  # start Postgres + MinIO + Dekart on :8080
```

Open http://localhost:8080 → **Create map** → click **💡 Start with a sample
query** (a menu of Germany examples), or paste one from
[`postgres-sample-queries.sql`](postgres-sample-queries.sql).

> Map **tiles** only render with a Mapbox token. Put one in `.env`
> (`DEKART_MAPBOX_TOKEN=pk...`) and run `./dekart.sh restart`. Layers/data work
> without it; only the basemap imagery is blank.

### `./dekart.sh` commands

| Command | What it does |
|---|---|
| `up` | Start the core stack (pg + minio + dekart) on :8080 |
| `bq` | Also start the BigQuery instance on :8081 (needs GCP — see below) |
| `ch` | Also start the Clickhouse instance on :8082 (fully local — see below) |
| `build` | Build the patched image + enable it (adds the **Import style** button) |
| `official` | Switch back to the official Dekart image |
| `down` | Stop & remove containers (keeps data) |
| `reset` | Stop & **wipe** all data (re-runs the SQL init on next `up`) |
| `restart` | Recreate the core stack (pick up `.env`/compose changes) |
| `status` | Container status |
| `logs [svc]` | Follow logs (default `dekart`; try `pg`, `minio`) |
| `psql` | Open `psql` against the sample database |

It auto-detects whether to use `docker` or `sudo docker`, and clears a leftover
standalone `dekart` container if one is holding port 8080.

## Sample data (schema `sample`)

| Table | Geometry | Columns |
|---|---|---|
| `geospatial_points` | points | `id, name, category, longitude, latitude, geom_wkt` (~70k Denmark POIs) |
| `germany_cities` | points | `name, state, latitude, longitude, population` (75 cities) |
| `germany_lines` | lines | `name, from_city, to_city, distance_km, geom_wkt, geometry` (14 corridors) |
| `germany_regions` | polygons | `region, n_cities, geom_wkt, geometry` (5 macro-region hulls) |

- For **points**, kepler auto-detects `latitude`/`longitude`.
- For **lines/polygons**, select the GeoJSON **`geometry`** column — kepler
  auto-detects it reliably (WKT in `geom_wkt` is kept for external SQL clients).

### Sample queries

See [`postgres-sample-queries.sql`](postgres-sample-queries.sql) — points,
category filters, bounding boxes, centroids (G1–G5), lines (G6, G8), polygons
(G7), and an optional PostGIS hull example.

```sql
-- points
SELECT name, state, latitude, longitude, population FROM sample.germany_cities;
-- lines   (run in a NEW map)
SELECT name, distance_km, geometry FROM sample.germany_lines;
-- polygons (run in a NEW map)
SELECT region, n_cities, geometry FROM sample.germany_regions;
```

**Show points + lines + polygons together** — query **G9** UNIONs all three
into one GeoJSON `geometry` column (city lat/lon becomes a GeoJSON Point), so a
single layer renders everything; color it by `kind`. Alternatively, add three
separate queries to one map (each becomes its own layer). With the patched image
you can import [`custom-image/styles/combined-style.json`](custom-image/styles/combined-style.json)
to style the combined layer.

> **Lines/polygons not showing?** Run each geometry query in a **new map**.
> When you change the SQL inside an existing map, Dekart replaces the data with
> `autoCreateLayers: false`, so it keeps the old layer and never creates a layer
> for the new geometry. A fresh map auto-creates it. (Or add it manually:
> Layers → **+ Add Layer** → pick the `geometry` column.)

## Saving / loading map styles

Dekart auto-saves each map's kepler config (layer styling, colors, base map)
with the report, and you can reuse it by **Fork/Duplicate** (the fork icon in
the map header) — the duplicate carries the style and rebinds it to new data.

For **portable style files**, build the patched image which adds an **Import
style** button:

```sh
./dekart.sh build               # builds dekart-custom:local and enables it
```

Then run the matching query and import a style from
[`custom-image/styles/`](custom-image/styles):
`points-style.json`, `lines-style.json`, `regions-style.json`. See
[`custom-image/README.md`](custom-image/README.md) for details. Revert anytime
with `./dekart.sh official`.

## Upload your own data (CSV / GeoJSON / Parquet)

File upload is enabled (`DEKART_ALLOW_FILE_UPLOAD=1`; files are stored in MinIO).
On the home page choose **Upload file** and drag in a file. A ready sample is
included: [`uploads/germany.geojson`](uploads/germany.geojson) — a single
FeatureCollection with city **points**, corridor **lines**, and region
**polygons** (each Feature has `kind`, `name`, `value`), so one upload shows all
three geometry types. Color the layer by `kind`.

## Agent integration (MCP)

Dekart exposes MCP tool endpoints so an agent (Claude / Codex) can build maps by
writing SQL against your data: `GET /api/v1/mcp/tools` and
`POST /api/v1/mcp/call`. On this local anonymous instance they need no token —
smoke-test them:

```sh
./mcp-smoke.sh          # lists the tool catalog + calls list_connections
```

These are a custom REST shape, not MCP-over-stdio, so the supported agent client
is Dekart's **geosql** skill rather than a raw `.mcp.json`:

```sh
pip install geosql && geosql        # installs the Claude/Codex skill
pip install dekart-cli && dekart init
```

Point it at `http://localhost:8080`, then ask Claude to build a map from
`sample.germany_cities` (or any table). The tools include `create_report`,
`create_query`, `run_query`, `update_report_map_config`, and more.

## Clickhouse data source (experimental, port 8082)

A fully-local second warehouse. Clickhouse exports query results to the same
MinIO via its `s3()` function, so no cloud is needed.

```sh
./dekart.sh ch          # starts clickhouse + dekart-ch on :8082
```

Open http://localhost:8082 and run:

```sql
SELECT name, state, latitude, longitude, population
FROM dekart_geo.germany_cities
ORDER BY population DESC;
```

> ⚠️ **Experimental / untested here.** Config is derived from the dekart source
> (`DEKART_DATASOURCE=CH`, `DEKART_CLICKHOUSE_DATA_CONNECTION`,
> `DEKART_CLICKHOUSE_S3_OUTPUT_LOCATION=s3://dekart/ch`, S3/MinIO). If a query
> fails, check `./dekart.sh logs dekart-ch` and `logs clickhouse` — Clickhouse's
> `s3()` export needs network access to `minio:9000` and the `dekart` bucket
> (both provided by the stack).

## How Dekart is configured

| Var | Value | Meaning |
|---|---|---|
| `DEKART_DATASOURCE` | `PG` | Query Postgres |
| `DEKART_POSTGRES_DATASOURCE_CONNECTION` | `postgres://dekart:dekart@pg:5432/dekart_geo?sslmode=disable` | The DB to query |
| `DEKART_STORAGE` | `S3` | Store query results in S3 (here: local MinIO) |
| `AWS_ENDPOINT` | `http://minio:9000` | Point the S3 client at local MinIO |
| `DEKART_CLOUD_STORAGE_BUCKET` | `dekart` | Results bucket (created by `createbucket`) |
| `DEKART_IMAGE` | unset → `dekartxyz/dekart` | Override to use the patched image |

Metadata stays on Dekart's built-in SQLite, so **no license key is required**
(Postgres as a *data source* is free; Postgres *metadata* would need a license).

> **Why MinIO and not `DEKART_STORAGE=PG`?** The Postgres "replay" storage path
> reads `created_at` from the SQLite metadata DB into a Go `time.Time`, which
> fails on SQLite (it returns a string) → 500 on the result CSV. S3/MinIO reads
> the timestamp from the stored object instead. MinIO console:
> http://localhost:9001 (minioadmin / minioadmin).

## BigQuery (optional — cloud only, port 8081)

> ⚠️ **Not testable locally.** BigQuery is a cloud warehouse; Dekart builds its
> BigQuery client with a fixed Google endpoint, so it can't use a local
> emulator. This section needs a real GCP project. Results still go to the local
> MinIO, so no GCS bucket or license is needed.

1. **Credentials** with `BigQuery Job User` + `BigQuery Data Viewer`:
   - *Service-account key (default):* save it as `creds/key.json` (git-ignored).
   - *gcloud ADC:* mount `~/.config/gcloud:/root/.config/gcloud:ro` in the
     `dekart-bq` service and drop `GOOGLE_APPLICATION_CREDENTIALS`
     (run `gcloud auth application-default login` first).
2. Set the project and start:
   ```sh
   echo 'GCP_PROJECT_ID=your-gcp-project' >> .env
   ./dekart.sh bq                 # starts dekart-bq on :8081
   ```
3. Open http://localhost:8081 and try a query from
   [`bigquery-sample-queries.sql`](bigquery-sample-queries.sql) (NYC Citi Bike,
   Chicago taxi, US state/county polygons via `ST_ASTEXT`, OSM POIs).

## Connect with your own SQL client

```
psql postgres://dekart:dekart@localhost:5433/dekart_geo
# host=localhost port=5433 db=dekart_geo user=dekart password=dekart
```

## Reset / cleanup

```sh
./dekart.sh down      # stop, keep data
./dekart.sh reset     # stop and wipe pg + minio volumes (re-imports on next up)
```

Changing any `init/*.sql` or `init/*.csv` requires `./dekart.sh reset` (Postgres
only runs the init scripts on a fresh data volume).
