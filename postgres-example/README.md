# Dekart + Postgres example

A self-contained example: a Postgres database preloaded with ~70k Denmark
points-of-interest, wired up as a Dekart **data source** you can query and map.

## What's inside

- `docker-compose.yml` — Postgres + MinIO + Dekart, networked together.
- `init/01-sample.sql` — loads the sample data on first start into
  `sample.geospatial_points` (`id, name, category, longitude, latitude, geom_wkt`).
- `init/denmark-pois.csv` — the source data (Denmark POIs).

How Dekart is configured (see the compose file):

| Var | Value | Meaning |
|---|---|---|
| `DEKART_DATASOURCE` | `PG` | Query Postgres |
| `DEKART_POSTGRES_DATASOURCE_CONNECTION` | `postgres://dekart:dekart@pg:5432/dekart_geo?sslmode=disable` | The DB to query |
| `DEKART_STORAGE` | `S3` | Store query results in S3 (here: local MinIO) |
| `AWS_ENDPOINT` | `http://minio:9000` | Point the S3 client at local MinIO |
| `DEKART_CLOUD_STORAGE_BUCKET` | `dekart` | Results bucket (created by the `createbucket` step) |

Metadata stays on Dekart's built-in SQLite, so **no license key is required**
(Postgres *metadata* would need one; Postgres as a *data source* does not).

> **Why MinIO and not `DEKART_STORAGE=PG`?** The Postgres "replay" storage path
> reads `created_at` from the SQLite metadata DB and scans it into a Go
> `time.Time` — which fails on SQLite (it returns a string), giving a 500 on the
> result CSV. S3/MinIO storage reads the timestamp from the stored object
> instead, so it works with SQLite metadata. MinIO runs locally — no cloud, no
> license. Its console is at http://localhost:9001 (minioadmin / minioadmin).

## Run it

```sh
# (optional) a Mapbox token so map tiles render
export DEKART_MAPBOX_TOKEN=pk.your_token

cd postgres-example
sudo docker compose up        # add -d to detach; drop `sudo` if you're in the docker group
```

Then open http://localhost:8080, click **Create map**, and run:

```sql
SELECT name, category, latitude, longitude, geom_wkt
FROM sample.geospatial_points
LIMIT 5000;
```

Kepler.gl auto-detects the `latitude`/`longitude` columns (or the `geom_wkt`
WKT column) and draws the points.

## Sample queries to try (local Postgres — runnable now)

The data source is already loaded; just paste a query into a map on
http://localhost:8080. See [`postgres-sample-queries.sql`](postgres-sample-queries.sql)
for points, category filters, bounding boxes, centroids, and a PostGIS
convex-hull example.

## BigQuery (cloud only — reference, needs a GCP account)

> ⚠️ **Not testable locally.** BigQuery is a cloud warehouse, and dekart builds
> its BigQuery client with a fixed Google endpoint — it can't be pointed at a
> local emulator without patching the source (and the emulator wouldn't support
> the public datasets or `ST_*` functions anyway). So this section only works
> once you have a real GCP project. The fully-local, runnable example is the
> Postgres stack above. The `bigquery-sample-queries.sql` file and the
> `dekart-bq` service are provided as ready-to-use reference for when you do
> have GCP access.

When you have a GCP account, this runs a **second instance on port 8081**.
You need:

1. A **GCP project** (queries are billed there; public data is free to read but
   you pay for bytes scanned — the compose sets a 1 TiB cap).
2. **Credentials** with `BigQuery Job User` + `BigQuery Data Viewer`.

Results are stored in the same local **MinIO**, so no GCS bucket or license is
needed.

### 1. Provide credentials

**Option A — service-account key (default):** download a key JSON and save it
as `creds/key.json` (git-ignored). The compose mounts it read-only.

**Option B — your gcloud login (ADC):** instead of a key file, edit the
`dekart-bq` service to mount your ADC and drop `GOOGLE_APPLICATION_CREDENTIALS`:

```yaml
    environment:
      # remove the GOOGLE_APPLICATION_CREDENTIALS line
    volumes:
      - ~/.config/gcloud:/root/.config/gcloud:ro
```
(run `gcloud auth application-default login` on the host first.)

### 2. Start it

```sh
export GCP_PROJECT_ID=your-gcp-project
export DEKART_MAPBOX_TOKEN=pk.your_token        # optional
docker compose --profile bq up -d               # starts dekart-bq too
```

Open **http://localhost:8081**, click **Create map**, and paste a query from
[`bigquery-sample-queries.sql`](bigquery-sample-queries.sql), e.g.:

```sql
SELECT name, latitude, longitude, capacity
FROM `bigquery-public-data.new_york_citibike.citibike_stations`
WHERE latitude IS NOT NULL
LIMIT 2000;
```

For polygons, convert GEOGRAPHY to WKT with `ST_ASTEXT(...)` (see samples 4–6).

## Connect with your own SQL client

```
host=localhost port=5433 db=dekart_geo user=dekart password=dekart
psql postgres://dekart:dekart@localhost:5433/dekart_geo
```

## Stop / reset

```sh
sudo docker compose down           # stop
sudo docker compose down -v        # stop and wipe the loaded data
```

> Note: this example publishes Dekart on port 8080. If you still have the
> standalone container from earlier running, stop it first:
> `sudo docker rm -f dekart`.
