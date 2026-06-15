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

## Build it

```sh
cd custom-image
./build.sh                 # builds dekart-custom:local (several minutes)
```

Then point the stack at the new image and restart:

```sh
echo 'DEKART_IMAGE=dekart-custom:local' >> ../.env
cd .. && ./dekart.sh restart
```

(`docker-compose.yml` uses `${DEKART_IMAGE:-dekartxyz/dekart}`, so without this
line it falls back to the official image.)

## Use it

1. Create a map and run a query:
   - **Points:** `SELECT name, state, latitude, longitude, population FROM sample.germany_cities;`
   - **Lines:**  `SELECT name, distance_km, geometry FROM sample.germany_lines;`
2. Click the **Import style** button (paint-drop icon) in the map header.
3. Pick `styles/points-style.json` (for the points query) or
   `styles/lines-style.json` (for the lines query).

The style applies to whatever dataset is loaded, regardless of its id. The
`mapState` in each file also recenters on Germany.

## Notes

- The style file's layer must match the query's columns: points expect
  `latitude`/`longitude` (+ `population`); lines expect a GeoJSON `geometry`
  column (+ `distance_km`). Run the matching query before importing.
- To make your own style: configure a map, then this same JSON shape is what
  Dekart stores per map — copy a working config and replace the `dataId` with
  `"REPLACE_ME"` (the button rebinds it on import).
