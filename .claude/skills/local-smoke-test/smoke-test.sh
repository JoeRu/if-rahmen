#!/usr/bin/env bash
# Local smoke-test docker-compose lifecycle helper.
#
# Usage (run from if-rahmen/ root, next to docker-compose.yml):
#   .claude/skills/local-smoke-test/smoke-test.sh check        # fail fast if nothing is already running
#   .claude/skills/local-smoke-test/smoke-test.sh rebuild-up   # docker compose build && up -d, wait for readiness
#   .claude/skills/local-smoke-test/smoke-test.sh down         # docker compose down
#
# Owns the container lifecycle only — never touches a browser and never
# modifies docker-compose.yml or Config-IF/.
set -euo pipefail

if [ ! -f docker-compose.yml ]; then
  echo "error: docker-compose.yml not found in the current directory — run this from the if-rahmen/ workspace root." >&2
  exit 1
fi

PORT=$(grep -oE '"[0-9]+:[0-9]+"' docker-compose.yml | head -1 | tr -d '"' | cut -d: -f1)
if [ -z "$PORT" ]; then
  PORT=2284
fi

wait_ready() {
  local timeout="$1" waited=0
  while ! curl -sf -o /dev/null "http://localhost:$PORT"; do
    if [ "$waited" -ge "$timeout" ]; then
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 0
}

cmd="${1:-}"
case "$cmd" in
  check)
    if wait_ready 6; then
      echo "ImmichFrame is responding on http://localhost:$PORT"
      exit 0
    else
      echo "error: nothing responding on http://localhost:$PORT. Did you mean 'rebuild-up'?" >&2
      exit 1
    fi
    ;;
  rebuild-up)
    docker compose build
    docker compose up -d
    if wait_ready 90; then
      echo "ImmichFrame is up and responding on http://localhost:$PORT"
      exit 0
    else
      echo "error: container did not become ready within 90s. Recent logs:" >&2
      docker compose logs --tail=50 >&2
      exit 1
    fi
    ;;
  down)
    docker compose down
    ;;
  *)
    echo "Usage: $0 <check|rebuild-up|down>" >&2
    exit 1
    ;;
esac
