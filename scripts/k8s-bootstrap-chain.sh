#!/usr/bin/env bash
# Helm Job: same order as docker compose dev_bootstrap → dev_branding → dev_seed.
# Runs inside gdcc/configbaker (bootstrap.sh) then applies branding + seed via curl scripts.
set -euo pipefail

# Bump when token / configbaker behavior changes (grep logs for this to confirm the cluster mounted an updated ConfigMap).
CHAIN_SCRIPT_REVISION=4
echo "k8s-bootstrap-chain: chain script revision=${CHAIN_SCRIPT_REVISION}" >&2

# Helm mounts our chain scripts here; must NOT use /scripts — that shadows gdcc/configbaker's /scripts/bootstrap.sh.
CHAIN_SCRIPTS="${BOOTSTRAP_CHAIN_SCRIPT_DIR:-/bootstrap-chain}"
CONFIGBAKER_BOOTSTRAP="${CONFIGBAKER_BOOTSTRAP_SH:-/scripts/bootstrap.sh}"

SECRETS_DIR="${DATAVERSE_BOOTSTRAP_SECRETS_DIR:-/secrets}"
TOKEN_FILE="${DATAVERSE_BOOTSTRAP_ENV_FILE:-${SECRETS_DIR}/api/bootstrap.env}"
WAIT_MAX="${BOOTSTRAP_CHAIN_WAIT_MAX_SECONDS:-900}"
SLEEP="${BOOTSTRAP_CHAIN_WAIT_SLEEP:-5}"

DATAVERSE_INTERNAL_URL="${DATAVERSE_INTERNAL_URL:-}"
if [[ -z "${DATAVERSE_INTERNAL_URL}" ]]; then
  echo "k8s-bootstrap-chain: DATAVERSE_INTERNAL_URL is required" >&2
  exit 1
fi

if [[ -n "${DATAVERSE_API_TOKEN:-}" ]]; then
  echo "k8s-bootstrap-chain: DATAVERSE_API_TOKEN is set from the environment (length=${#DATAVERSE_API_TOKEN})" >&2
else
  echo "k8s-bootstrap-chain: DATAVERSE_API_TOKEN is unset (first install is OK; already-bootstrapped needs a Secret — see values bootstrapJob.compose.existingAdminApiTokenSecret)" >&2
fi

try_version() {
  curl -sf --max-time 15 "${DATAVERSE_INTERNAL_URL%/}/api/info/version" >/dev/null 2>&1
}

echo "k8s-bootstrap-chain: waiting for Dataverse at ${DATAVERSE_INTERNAL_URL} (max ${WAIT_MAX}s) ..." >&2
elapsed=0
while [[ "${elapsed}" -lt "${WAIT_MAX}" ]]; do
  if try_version; then
    echo "k8s-bootstrap-chain: Dataverse API is up" >&2
    break
  fi
  sleep "${SLEEP}"
  elapsed=$((elapsed + SLEEP))
done
if ! try_version; then
  echo "k8s-bootstrap-chain: timeout — Dataverse not reachable" >&2
  exit 1
fi

write_api_key_from_token() {
  local tok="$1"
  mkdir -p "${SECRETS_DIR}/api"
  umask 077
  printf '%s\n' "${tok}" >"${SECRETS_DIR}/api/key.tmp"
  mv "${SECRETS_DIR}/api/key.tmp" "${SECRETS_DIR}/api/key"
  export DATAVERSE_API_TOKEN="${tok}"
}

# Skip configbaker (e.g. post-upgrade Helm hook): supply DATAVERSE_API_TOKEN from env / secretRef.
if [[ "${BOOTSTRAP_CHAIN_SKIP_BOOTSTRAP:-}" == 1 ]]; then
  if [[ -z "${DATAVERSE_API_TOKEN:-}" ]]; then
    echo "k8s-bootstrap-chain: BOOTSTRAP_CHAIN_SKIP_BOOTSTRAP=1 requires DATAVERSE_API_TOKEN" >&2
    exit 2
  fi
  echo "k8s-bootstrap-chain: skipping bootstrap.sh (using existing admin API token)" >&2
  write_api_key_from_token "${DATAVERSE_API_TOKEN}"
else
  # Secret (optional ref) + non-empty token: skip configbaker — it only prints "already bootstrapped" and leaves no API_TOKEN in bootstrap.env.
  if [[ -n "${DATAVERSE_API_TOKEN:-}" ]]; then
    echo "k8s-bootstrap-chain: skipping configbaker — using DATAVERSE_API_TOKEN from environment" >&2
    write_api_key_from_token "${DATAVERSE_API_TOKEN}"
  else
    mkdir -p "$(dirname "${TOKEN_FILE}")"
    if [[ -d "${TOKEN_FILE}" ]]; then
      echo "k8s-bootstrap-chain: ${TOKEN_FILE} is a directory" >&2
      exit 3
    fi
    umask 077
    [[ -f "${TOKEN_FILE}" ]] || : >"${TOKEN_FILE}"

    echo "k8s-bootstrap-chain: running configbaker (${CONFIGBAKER_BOOTSTRAP} -e ${TOKEN_FILE} dev) ..." >&2
    if [[ ! -x "${CONFIGBAKER_BOOTSTRAP}" ]]; then
      echo "k8s-bootstrap-chain: ${CONFIGBAKER_BOOTSTRAP} missing or not executable (is /scripts shadowed by a volume mount?)" >&2
      exit 127
    fi
    "${CONFIGBAKER_BOOTSTRAP}" -e "${TOKEN_FILE}" dev

    # Kubernetes may inject DATAVERSE_API_TOKEN via secretKeyRef; configbaker's bootstrap.env can still
    # assign empty vars — sourcing must not wipe that token.
    DATAVERSE_API_TOKEN_PRE_SOURCE="${DATAVERSE_API_TOKEN:-}"

    # shellcheck disable=SC1090
    set +e
    [[ -f "${TOKEN_FILE}" ]] && source "${TOKEN_FILE}"
    set -e

    if [[ -n "${API_TOKEN:-}" ]]; then
      write_api_key_from_token "${API_TOKEN}"
    elif [[ -n "${DATAVERSE_API_TOKEN:-}" ]]; then
      echo "k8s-bootstrap-chain: no API_TOKEN in ${TOKEN_FILE} (configbaker often skips when already bootstrapped); using DATAVERSE_API_TOKEN from environment" >&2
      write_api_key_from_token "${DATAVERSE_API_TOKEN}"
    elif [[ -n "${DATAVERSE_API_TOKEN_PRE_SOURCE:-}" ]]; then
      echo "k8s-bootstrap-chain: no API_TOKEN in ${TOKEN_FILE}; bootstrap.env cleared DATAVERSE_API_TOKEN — using token from environment (e.g. Secret) before source" >&2
      write_api_key_from_token "${DATAVERSE_API_TOKEN_PRE_SOURCE}"
    else
      echo "k8s-bootstrap-chain: no API_TOKEN after configbaker and no usable DATAVERSE_API_TOKEN." >&2
      echo "k8s-bootstrap-chain: fix: kubectl create secret generic ... --from-literal=token=SUPERUSER_UUID and set bootstrapJob.compose.existingAdminApiTokenSecret (see ops/demo-deploy.tmpl.yaml)." >&2
      echo "k8s-bootstrap-chain: if startup logs lack \"chain script revision=${CHAIN_SCRIPT_REVISION}\", the Helm bootstrap-chain ConfigMap is stale — helm upgrade the release or kubectl apply the rendered templates/bootstrap-chain-configmap.yaml manifest." >&2
      exit 2
    fi
  fi
fi

export BRANDING_ENV_PATH="${BRANDING_ENV_PATH:-/config/branding.env}"
if [[ -f "${BRANDING_ENV_PATH}" ]]; then
  echo "k8s-bootstrap-chain: apply-branding ..." >&2
  export DATAVERSE_INTERNAL_URL
  /bin/sh "${CHAIN_SCRIPTS}/apply-branding.sh"
else
  echo "k8s-bootstrap-chain: skip branding (no ${BRANDING_ENV_PATH})" >&2
fi

layout_seed_from_flat_mount() {
  # ConfigMap keys cannot contain '/'; flat keys may be mounted under /seed-flat.
  [[ -d /seed-flat ]] || return 0
  mkdir -p /fixtures/seed/files
  for f in demo-collection.json dataset-images.json dataset-tabular.json; do
    [[ -f "/seed-flat/${f}" ]] && cp "/seed-flat/${f}" "/fixtures/seed/${f}"
  done
  for pair in "files_1x1.png:1x1.png" "files_badge.svg:badge.svg" "files_readme.txt:readme.txt" "files_sample.csv:sample.csv"; do
    key="${pair%%:*}"
    name="${pair##*:}"
    [[ -f "/seed-flat/${key}" ]] && cp "/seed-flat/${key}" "/fixtures/seed/files/${name}"
  done
}

if [[ "${BOOTSTRAP_CHAIN_SEED:-1}" == "1" ]]; then
  layout_seed_from_flat_mount
fi

if [[ "${BOOTSTRAP_CHAIN_SEED:-1}" == "1" ]] && [[ -f /fixtures/seed/demo-collection.json ]]; then
  echo "k8s-bootstrap-chain: seed-content ..." >&2
  export SEED_FIXTURE="${SEED_FIXTURE:-/fixtures/seed/demo-collection.json}"
  export SEED_ROOT="${SEED_ROOT:-/fixtures/seed}"
  export SEED_PARENT_ALIAS="${SEED_PARENT_ALIAS:-root}"
  /bin/sh "${CHAIN_SCRIPTS}/seed-content.sh"
else
  echo "k8s-bootstrap-chain: skip seed (BOOTSTRAP_CHAIN_SEED=${BOOTSTRAP_CHAIN_SEED:-} or no fixtures)" >&2
fi

echo "k8s-bootstrap-chain: done" >&2
