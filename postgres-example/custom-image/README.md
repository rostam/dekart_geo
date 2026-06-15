# Patched Dekart image — "Import style" button

The stock Dekart has no UI to load a standalone style file (and kepler layer
styles are bound to a dataset id). This patch adds an **Import style** button to
the map header that reads a kepler config `.json`, **rebinds its `dataId`** to
the current map's dataset, and applies it — so the style files in `styles/`
become genuinely loadable and portable.

## Contents

- `import-style.patch` — frontend diff (adds the button + `applyStyleConfig`),
  pinned to dekart `45b5b54`.
- `build.sh` — clones that commit, applies the patch, builds `dekart-custom:local`.
- `styles/points-style.json` — point map: cities colored & sized by population.
- `styles/lines-style.json` — line map: corridors colored by distance.
- `styles/regions-style.json` — polygon map: region hulls filled by city count.

## Build it (one command)

```sh
cd ..                      # postgres-example/
./dekart.sh build          # builds dekart-custom:local, sets DEKART_IMAGE, restarts
```

`./dekart.sh build` runs `custom-image/build.sh`, writes `DEKART_IMAGE=dekart-custom:local`
into `.env`, and recreates the stack. To go back to the official image:
`./dekart.sh official`.

(`docker-compose.yml` uses `${DEKART_IMAGE:-dekartxyz/dekart}`, so without that
`.env` line it falls back to the official image. You can also run
`custom-image/build.sh` directly if you prefer to set `DEKART_IMAGE` yourself.)

## Use it

1. Create a map and run the matching query:
   - **Points:** `SELECT name, state, latitude, longitude, population FROM sample.germany_cities;`
   - **Lines:**  `SELECT name, distance_km, geometry FROM sample.germany_lines;`
   - **Polygons:** `SELECT region, n_cities, geometry FROM sample.germany_regions;`
2. Click the **Import style** button (paint-drop icon) in the map header.
3. Pick the matching file: `styles/points-style.json`, `styles/lines-style.json`,
   or `styles/regions-style.json`.

The style applies to whatever dataset is loaded, regardless of its id. The
`mapState` in each file also recenters on Germany.

## Notes

- The style file's layer must match the query's columns: points expect
  `latitude`/`longitude` (+ `population`); lines expect a GeoJSON `geometry`
  column (+ `distance_km`). Run the matching query before importing.
- To make your own style: configure a map, then this same JSON shape is what
  Dekart stores per map — copy a working config and replace the `dataId` with
  `"REPLACE_ME"` (the button rebinds it on import).
