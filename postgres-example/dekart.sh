#!/usr/bin/env bash
# Control script for the Dekart example stack (Postgres + MinIO + Dekart).
#
# Usage:
#   ./dekart.sh up         # start core stack (pg + minio + dekart) on :8080
#   ./dekart.sh bq         # also start the BigQuery instance on :8081 (needs GCP)
#   ./dekart.sh down       # stop & remove containers (keeps data)
#   ./dekart.sh reset      # stop & WIPE all data (postgres + minio volumes)
#   ./dekart.sh restart    # recreate the core stack
#   ./dekart.sh status     # show container status
#   ./dekart.sh logs [svc] # follow logs (default: dekart)
#   ./dekart.sh psql       # open psql against the sample database
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# --- pick docker invocation: direct if we have socket access, else sudo ---
if docker info >/dev/null 2>&1; then
  DC="docker compose"
elif sudo -n docker info >/dev/null 2>&1; then
  DC="sudo docker compose"
else
  DC="sudo docker compose"
  echo "Note: using 'sudo docker' (your user isn't in the 'docker' group)."
  echo "      To drop sudo: sudo usermod -aG docker \$USER  then open a new shell."
fi

# Compose reads ./.env automatically for DEKART_MAPBOX_TOKEN / GCP_PROJECT_ID.
ensure_env() {
  if [[ ! -f .env && -f .env.sample ]]; then
    cp .env.sample .env
    echo "Created .env from .env.sample — edit it to set DEKART_MAPBOX_TOKEN (and GCP_PROJECT_ID for bq)."
  fi
}

free_8080() {
  # The standalone single-container dekart (from ../run.sh) clashes on :8080.
  if ${DC%% compose} ps --format '{{.Names}}' 2>/dev/null | grep -qx dekart; then
    echo "Removing the standalone 'dekart' container that holds port 8080..."
    ${DC%% compose} rm -f dekart >/dev/null 2>&1 || true
  fi
}

urls() {
  echo "Dekart (Postgres): http://localhost:8080"
  [[ "${1:-}" == "bq" ]] && echo "Dekart (BigQuery): http://localhost:8081"
  echo "MinIO console:     http://localhost:9001  (minioadmin / minioadmin)"
}

case "${1:-up}" in
  up|start)
    ensure_env; free_8080
    $DC up -d
    echo; urls
    ;;
  bq)
    ensure_env; free_8080
    if ! grep -qsE '^GCP_PROJECT_ID=.+' .env && [[ -z "${GCP_PROJECT_ID:-}" ]]; then
      echo "ERROR: set GCP_PROJECT_ID in .env (and put a key at creds/key.json). See README."; exit 1
    fi
    [[ -f creds/key.json ]] || { echo "ERROR: creds/key.json missing. See README (or use gcloud ADC)."; exit 1; }
    $DC --profile bq up -d
    echo; urls bq
    ;;
  down|stop)    $DC --profile bq down ;;
  reset)        $DC --profile bq down -v; echo "All data wiped." ;;
  restart)      ensure_env; free_8080; $DC up -d --force-recreate; echo; urls ;;
  status|ps)    $DC --profile bq ps ;;
  logs)         $DC logs -f "${2:-dekart}" ;;
  psql)         $DC exec pg psql -U dekart -d dekart_geo ;;
  *)            echo "Usage: $0 {up|bq|down|reset|restart|status|logs [svc]|psql}"; exit 1 ;;
esac
