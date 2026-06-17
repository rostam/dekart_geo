# Build & run Dekart on Windows without Docker

Dekart is a **Go** server that embeds/serves a **React + Kepler.gl** frontend.
You can build and run it natively on Windows — no Docker required. The proto
stubs are committed, so you do **not** need `protoc`.

Two wrinkles on Windows:

1. The metadata store uses **SQLite via `mattn/go-sqlite3`**, which needs **CGO**
   → you need a **gcc** toolchain (MinGW-w64).
2. The `proto-copy-to-node` npm script is written for a Unix shell (`sh`/`cp`).
   We work around it with PowerShell (or just use Git Bash).

> Verified against Dekart `main` (Go 1.25, Node 18 in the official Dockerfile).
> Steps are derived from the project's `Dockerfile`; adjust versions if the repo
> moves on. Tested logic, not on a physical Windows box — file an issue if a
> step drifts.

---

## 1. Prerequisites

Install these (e.g. with [winget](https://learn.microsoft.com/windows/package-manager/) or [Scoop](https://scoop.sh)):

| Tool | Version | winget | notes |
|---|---|---|---|
| Git | any | `winget install Git.Git` | |
| Go | **1.25+** | `winget install GoLang.Go` | |
| Node.js | **18 LTS+** (18/20/22) | `winget install OpenJS.NodeJS.LTS` | includes npm |
| MinGW-w64 gcc | recent | `winget install BrechtSanders.WinLibs.POSIX.UCRT` | provides `gcc` for CGO |

Verify in a **new** PowerShell window (so PATH is fresh):

```powershell
git --version
go version          # go1.25+
node -v ; npm -v    # node v18+
gcc --version       # must resolve — required for CGO/SQLite
```

If `gcc` isn't found, add its `bin` folder to PATH (WinLibs installs to e.g.
`C:\winlibs\mingw64\bin`) and open a new terminal.

---

## 2. Clone

```powershell
git clone https://github.com/dekart-xyz/dekart.git
cd dekart
```

Run all later commands from this **repo root** (the server loads migrations from
relative paths `sqlite/migrations` and `migrations`).

---

## 3. Build the frontend → `build/`

The `npm ci` postinstall hook uses a Unix shell, so skip scripts and copy the
proto stubs manually (pure PowerShell):

```powershell
npm ci --ignore-scripts

# replicate "npm run proto-copy-to-node"
Remove-Item -Recurse -Force node_modules\dekart-proto, node_modules\.vite -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force node_modules\dekart-proto | Out-Null
Copy-Item -Recurse -Force proto\* node_modules\dekart-proto\

# build the static site into .\build
$env:NODE_OPTIONS = "--max-old-space-size=4096"
npm run build
```

> **Simpler alternative:** if you have **Git Bash** (ships with Git for Windows),
> just run `npm ci && npm run build` inside Git Bash — the `sh`/`cp` script works
> there and no manual copy is needed.

You should now have a `build\` folder with `index.html` and hashed JS/CSS.

---

## 4. Build the backend → `server.exe`

SQLite needs CGO, so gcc must be on PATH:

```powershell
$env:CGO_ENABLED = "1"
go build -o server.exe ./src/server
```

First build downloads modules and compiles SQLite via gcc — give it a few
minutes. Result: `server.exe` in the repo root.

---

## 5. Run it (zero-config, SQLite + local files)

Create `run-dekart.ps1` in the repo root:

```powershell
# run-dekart.ps1 — run Dekart locally on http://localhost:8080
$env:DEKART_PORT             = "8080"
$env:DEKART_STATIC_FILES     = "./build"
$env:DEKART_SQLITE_DB_PATH   = "./data/dekart.db"
$env:DEKART_STORAGE          = "USER"     # store results/uploads on local disk
$env:DEKART_DATASOURCE       = "USER"     # add connections in the UI
$env:DEKART_ALLOW_FILE_UPLOAD = "1"
$env:DEKART_LOCAL_FILES_ROOT = "./data/files"
# optional: map tiles
# $env:DEKART_MAPBOX_TOKEN   = "pk.your_token"

New-Item -ItemType Directory -Force .\data\files | Out-Null
.\server.exe
```

Run it and open the app:

```powershell
.\run-dekart.ps1
# then browse to http://localhost:8080
```

On first start it applies SQLite migrations and serves the UI. With
`DATASOURCE=USER` you add a connection (Postgres, BigQuery, …) from the UI;
or set warehouse env vars (e.g. `DEKART_DATASOURCE=PG` +
`DEKART_POSTGRES_DATASOURCE_CONNECTION=...`) like the Docker setup.

---

## Alternative: dev mode (hot-reload frontend)

Run the Go backend and the Vite dev server separately:

```powershell
# terminal 1 — backend on :8080 (env as in run-dekart.ps1, build step optional)
$env:CGO_ENABLED="1"; go run ./src/server

# terminal 2 — frontend dev server on :3000
npm start            # vite dev; proxies API to VITE_API_HOST (http://localhost:8080)
```

Open http://localhost:3000. (`.env.development` already sets
`VITE_API_HOST=http://localhost:8080`.)

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `gcc: executable file not found` / `cgo: C compiler ... not found` | Install MinGW-w64 and add its `bin` to PATH; reopen terminal; `CGO_ENABLED=1`. |
| `Binary was compiled with 'CGO_ENABLED=0'` / sqlite errors | You built without CGO. Set `$env:CGO_ENABLED="1"` and rebuild. |
| `'sh' is not recognized` during `npm ci` | Use `--ignore-scripts` + manual proto copy (Step 3), or run npm in Git Bash. |
| `Cannot find module 'dekart-proto/...'` at build | The proto copy didn't run — redo the `Copy-Item proto\*` step. |
| Migrations / "no such table" at startup | Run `server.exe` from the **repo root** so `sqlite/migrations` resolves. |
| `DEKART_SQLITE_DB_PATH is required` | Set it (Step 5); the parent folder must exist. |
| Map area blank | Set `DEKART_MAPBOX_TOKEN`; data layers still render without it. |
| Node out-of-memory during `npm run build` | `$env:NODE_OPTIONS="--max-old-space-size=4096"`. |
