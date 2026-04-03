#!/bin/sh
# Before apply-branding: if secrets/api/key is empty, copy API_TOKEN from secrets/api/bootstrap.env
# (written by configbaker dev bootstrap via bootstrap.sh -e /secrets/api/bootstrap.env dev).
set -eu

if [ ! -s /secrets/api/key ] && [ -f /secrets/api/bootstrap.env ]; then
  # shellcheck disable=SC1090
  . /secrets/api/bootstrap.env
  if [ -n "${API_TOKEN:-}" ]; then
    umask 077
    printf '%s\n' "$API_TOKEN" > /secrets/api/key.tmp
    mv /secrets/api/key.tmp /secrets/api/key
    echo "dev_branding: wrote /secrets/api/key from api/bootstrap.env (admin API_TOKEN from dev bootstrap)" >&2
  fi
fi

exec /bin/sh /scripts/apply-branding.sh
