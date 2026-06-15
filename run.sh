#!/usr/bin/env bash
# Run dekart locally via Docker.
# Usage:
#   ./run.sh            # start (pull if needed) and follow logs
#   ./run.sh start      # start detached
#   ./run.sh logs       # follow logs
#   ./run.sh stop       # stop & remove the container
#   ./run.sh restart    # recreate the container
set -euo pipefail

NAME="dekart"
IMAGE="dekartxyz/dekart"
PORT="${DEKART_PORT:-8080}"
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env"

# --- pick docker invocation: direct if we have socket access, else sudo ---
if docker info >/dev/null 2>&1; then
  DOCKER="docker"
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER="sudo docker"
else
  DOCKER="sudo docker"
  echo "Note: using 'sudo docker' (your user isn't in the 'docker' group)."
  echo "      To drop sudo: sudo usermod -aG docker \$USER  then open a new shell."
fi

ensure_env() {
  if [[ ! -f "$ENV_FILE" && -f "${ENV_FILE%.*}.example" ]]; then
    cp "$(dirname "$ENV_FILE")/.env.example" "$ENV_FILE"
    echo "Created .env from .env.example — edit it to set DEKART_MAPBOX_TOKEN etc."
  fi
}

start() {
  ensure_env
  $DOCKER rm -f "$NAME" >/dev/null 2>&1 || true

  args=(run -d --name "$NAME" -p "${PORT}:8080")
  if [[ -f "$ENV_FILE" ]]; then
    args+=(--env-file "$ENV_FILE")
  fi
  # Pass local gcloud creds through when using BigQuery/GCS.
  if [[ -f "$ENV_FILE" ]] && grep -qE '^DEKART_DATASOURCE=BQ' "$ENV_FILE" && [[ -d "$HOME/.config/gcloud" ]]; then
    args+=(-v "$HOME/.config/gcloud:/root/.config/gcloud")
  fi
  args+=("$IMAGE")

  echo "Starting $NAME on http://localhost:${PORT} ..."
  $DOCKER "${args[@]}"
  echo "Open http://localhost:${PORT}"
}

case "${1:-up}" in
  up)      start; echo "Following logs (Ctrl-C to detach)..."; $DOCKER logs -f "$NAME" ;;
  start)   start ;;
  restart) start ;;
  stop)    $DOCKER rm -f "$NAME" >/dev/null 2>&1 && echo "Stopped & removed $NAME." || echo "$NAME not running." ;;
  logs)    $DOCKER logs -f "$NAME" ;;
  *)       echo "Usage: $0 {up|start|stop|restart|logs}"; exit 1 ;;
esac
