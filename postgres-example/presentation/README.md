# Dekart usage — presentation

A [Marp](https://marp.app) slide deck on what Dekart is and the different ways
to use it.

- **`dekart-usage.md`** — the source (plain Markdown / Marp).
- **`dekart-usage.pdf`** — rendered slides (share this).
- **`dekart-usage.html`** — rendered slides for the browser.
- **`images/`** — architecture diagram (SVG) + real screenshots of the running app.

## Rebuild

```sh
cd presentation
# HTML
npx -y @marp-team/marp-cli@latest dekart-usage.md -o dekart-usage.html --allow-local-files
# PDF (needs a Chrome/Chromium)
CHROME_PATH=/usr/bin/google-chrome \
  npx -y @marp-team/marp-cli@latest dekart-usage.md -o dekart-usage.pdf --allow-local-files --pdf
# PPTX (editable in PowerPoint/Keynote)
CHROME_PATH=/usr/bin/google-chrome \
  npx -y @marp-team/marp-cli@latest dekart-usage.md -o dekart-usage.pptx --allow-local-files --pptx
```

Or use the **Marp for VS Code** extension to preview/export.

## Refresh the screenshots

The PNGs were captured from the running stack (`./dekart.sh up`, then create a
map and run a sample query). Map basemap tiles need a Mapbox token
(`DEKART_MAPBOX_TOKEN` in `.env`); data layers render without one.
