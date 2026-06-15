#!/usr/bin/env bash
# Smoke-test Dekart's MCP HTTP endpoints — the same ones the `geosql` agent
# skill drives. Works against the local anonymous instance with no token.
#
#   ./mcp-smoke.sh                 # against http://localhost:8080
#   DEKART_URL=http://host:8080 ./mcp-smoke.sh
set -euo pipefail
BASE="${DEKART_URL:-http://localhost:8080}"

echo "==> GET $BASE/api/v1/mcp/tools  (tool catalog)"
curl -fsS "$BASE/api/v1/mcp/tools" | python3 -m json.tool | head -60

echo
echo "==> POST $BASE/api/v1/mcp/call  (list_connections)"
curl -fsS -X POST "$BASE/api/v1/mcp/call" \
  -H 'Content-Type: application/json' \
  -d '{"name":"list_connections","arguments":{}}' | python3 -m json.tool
