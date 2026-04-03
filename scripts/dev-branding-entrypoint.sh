#!/bin/sh
# Before apply-branding: copy API_TOKEN from secrets/api/bootstrap.env into secrets/api/key when set.
# (Written by configbaker dev bootstrap via bootstrap.sh -e /secrets/api/bootstrap.env dev.)
# Always refresh when API_TOKEN is present so a stale non-empty api/key after `down -v` does not break API calls.
set -eu

if [ -f /secrets/api/bootstrap.env ]; then
  # shellcheck disable=SC1090
  . /secrets/api/bootstrap.env
  if [ -n "${API_TOKEN:-}" ]; then
    umask 077
    printf '%s\n' "$API_TOKEN" > /secrets/api/key.tmp
    mv /secrets/api/key.tmp /secrets/api/key
    echo "dev_branding: refreshed /secrets/api/key from api/bootstrap.env (admin API_TOKEN from dev bootstrap)" >&2
  fi
fi

exec /bin/sh /scripts/apply-branding.sh
