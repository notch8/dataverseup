#!/bin/sh
# Wait for Dataverse API, then match dev-branding token copy, then seed.
set -eu

PRIMARY="${DATAVERSE_INTERNAL_URL:-http://dataverse:8080}"
FALLBACK="${DATAVERSE_INTERNAL_URL_FALLBACK:-}"
MAX="${SEED_WAIT_MAX_SECONDS:-600}"
SLEEP=5
elapsed=0

try_version() {
  _base="$1"
  curl -sf --max-time 10 "${_base%/}/api/info/version" >/dev/null 2>&1
}

pick_base_url() {
  if try_version "$PRIMARY"; then
    printf '%s' "$PRIMARY"
    return 0
  fi
  if [ -n "$FALLBACK" ] && try_version "$FALLBACK"; then
    printf '%s' "$FALLBACK"
    return 0
  fi
  return 1
}

echo "dev_seed: waiting for Dataverse (primary=${PRIMARY}${FALLBACK:+ fallback=${FALLBACK}})..." >&2
while [ "$elapsed" -lt "$MAX" ]; do
  if picked=$(pick_base_url); then
    export DATAVERSE_INTERNAL_URL="$picked"
    echo "dev_seed: Dataverse OK at ${DATAVERSE_INTERNAL_URL}" >&2
    break
  fi
  elapsed=$((elapsed + SLEEP))
  sleep "$SLEEP"
done

if ! try_version "${DATAVERSE_INTERNAL_URL:-}"; then
  echo "dev_seed: timed out after ${MAX}s — Dataverse not reachable." >&2
  echo "dev_seed: Run from this repo: docker compose up -d, wait for health, then docker compose run --rm dev_seed" >&2
  echo "dev_seed: Do not use --no-deps (seed must share the compose network with dataverse)." >&2
  exit 1
fi

# Always refresh api/key from bootstrap when API_TOKEN is set. Host secrets survive
# `docker compose down -v`; a non-empty but stale api/key would otherwise skip copy and cause HTTP 401.
if [ -f /secrets/api/bootstrap.env ]; then
  # shellcheck disable=SC1090
  . /secrets/api/bootstrap.env
  if [ -n "${API_TOKEN:-}" ]; then
    umask 077
    printf '%s\n' "$API_TOKEN" > /secrets/api/key.tmp
    mv /secrets/api/key.tmp /secrets/api/key
    echo "dev_seed: refreshed /secrets/api/key from api/bootstrap.env" >&2
  fi
fi

exec /bin/sh /scripts/seed-content.sh
