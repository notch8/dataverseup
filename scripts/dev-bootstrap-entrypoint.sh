#!/usr/bin/env bash
# dev_bootstrap: ensure bootstrap.sh -e target is a writable regular file, then run dev persona.
set -euo pipefail
TOKEN_FILE="${DATAVERSE_BOOTSTRAP_ENV_FILE:-/secrets/api/bootstrap.env}"
mkdir -p "$(dirname "$TOKEN_FILE")"
if [ -d "$TOKEN_FILE" ]; then
  echo "dev_bootstrap: ${TOKEN_FILE} is a directory; remove it on the host (must be a regular file)." >&2
  exit 3
fi
if [ ! -f "$TOKEN_FILE" ]; then
  umask 077
  : > "$TOKEN_FILE"
fi
exec bootstrap.sh -e "$TOKEN_FILE" dev
