#!/usr/bin/env bash
# Bring up the stack and re-apply branding (same idea as demo-dataverse bin/dev-up).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Copy .env.example to .env first." >&2
  exit 1
fi
if [[ ! -d secrets ]]; then
  echo "Copy secrets.example to secrets first (see secrets.example/README.md)." >&2
  exit 1
fi

docker compose up -d
docker compose run --rm dev_branding
