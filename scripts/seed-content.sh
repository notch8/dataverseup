#!/bin/sh
# Ensure demo sub-dataverse exists, then seed datasets + files via Native API (idempotent per dataset marker).
# Token: DATAVERSE_API_TOKEN or /secrets/api/key. See dev-seed-entrypoint.sh.
# Env: DATAVERSE_INTERNAL_URL, SEED_FIXTURE, SEED_PARENT_ALIAS, SEED_ROOT,
#      SEED_PUBLISH_MAX_ATTEMPTS, SEED_PUBLISH_RETRY_SLEEP (403 while tabular ingest runs).

set -eu

BASE_URL="${DATAVERSE_INTERNAL_URL:-http://dataverse:8080}"
API="${BASE_URL%/}/api"
FIXTURE="${SEED_FIXTURE:-/fixtures/seed/demo-collection.json}"
PARENT="${SEED_PARENT_ALIAS:-root}"
SEED_ROOT="${SEED_ROOT:-/fixtures/seed}"

if [ -n "${DATAVERSE_API_TOKEN:-}" ]; then
  TOKEN="$DATAVERSE_API_TOKEN"
elif [ -r /secrets/api/key ]; then
  TOKEN=$(tr -d '[:space:]' </secrets/api/key)
else
  TOKEN=""
fi

if [ -z "$TOKEN" ]; then
  echo "seed-content: no DATAVERSE_API_TOKEN and no readable /secrets/api/key" >&2
  echo "seed-content: run dev_bootstrap first or place the admin token in secrets/api/key" >&2
  exit 1
fi

if [ ! -r "$FIXTURE" ]; then
  echo "seed-content: fixture not readable: $FIXTURE" >&2
  exit 1
fi

CHILD_ALIAS="${SEED_CHILD_ALIAS:-}"
if [ -z "$CHILD_ALIAS" ]; then
  CHILD_ALIAS=$(grep '"alias"' "$FIXTURE" | head -1 | sed -n 's/^[[:space:]]*"alias"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi
if [ -z "$CHILD_ALIAS" ]; then
  echo "seed-content: could not parse alias from $FIXTURE; set SEED_CHILD_ALIAS" >&2
  exit 1
fi

# --- URL-encode persistent id for query string (minimal : and /).
encode_pid() {
  printf '%s' "$1" | sed -e 's/:/%3A/g' -e 's|/|%2F|g'
}

contents_has_marker() {
  _dv=$1
  _mark=$2
  _body=$(curl -sS --max-time 60 -H "X-Dataverse-key: ${TOKEN}" "${API}/dataverses/${_dv}/contents") || return 1
  printf '%s' "$_body" | grep -q "$_mark"
}

ensure_subdataverse() {
  printf '%s\n' "seed-content: parent=${PARENT} child_alias=${CHILD_ALIAS} fixture=${FIXTURE}" >&2
  _code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 30 \
    -H "X-Dataverse-key: ${TOKEN}" \
    "${API}/dataverses/${CHILD_ALIAS}" || printf '%s' "000")

  case "$_code" in
    200)
      echo "seed-content: dataverse '${CHILD_ALIAS}' already exists" >&2
      ;;
    404)
      curl -fsS --max-time 120 -X POST \
        -H "X-Dataverse-key: ${TOKEN}" \
        -H "Content-Type: application/json" \
        --data-binary "@${FIXTURE}" \
        "${API}/dataverses/${PARENT}"
      echo "" >&2
      echo "seed-content: created dataverse '${CHILD_ALIAS}' under '${PARENT}'" >&2
      ;;
    000)
      echo "seed-content: GET ${API}/dataverses/${CHILD_ALIAS} failed (network?)" >&2
      exit 1
      ;;
    401)
      echo "seed-content: GET ${API}/dataverses/${CHILD_ALIAS} -> HTTP 401 (invalid API token; check secrets/api/bootstrap.env API_TOKEN and secrets/api/key, or run dev_bootstrap)" >&2
      exit 1
      ;;
    *)
      echo "seed-content: unexpected GET ${API}/dataverses/${CHILD_ALIAS} -> HTTP ${_code}" >&2
      exit 1
      ;;
  esac
}

extract_persistent_id() {
  printf '%s' "$1" | tr -d '\n\r' | grep -o '"persistentId":"[^"]*"' | head -1 | cut -d'"' -f4
}

upload_file() {
  _pid=$1
  _path=$2
  _dir=$3
  _tab=$4
  _enc=$(encode_pid "$_pid")
  # Booleans must be JSON true/false (not quoted strings); include categories per Native API examples.
  _json=$(printf '{"description":"DataverseUp seed","directoryLabel":"%s","restrict":false,"tabIngest":%s,"categories":["Data"]}' "$_dir" "$_tab")
  _resp=$(curl -sS --max-time 300 --globoff -X POST \
    -H "X-Dataverse-key: ${TOKEN}" \
    -F "file=@${_path}" \
    -F "jsonData=${_json}" \
    -w "\n%{http_code}" \
    "${API}/datasets/:persistentId/add?persistentId=${_enc}" || printf '%s\n' "000")
  _code=$(printf '%s\n' "$_resp" | tail -n 1)
  _body=$(printf '%s\n' "$_resp" | sed '$d')
  case "$_code" in
    200|201|204)
      return 0
      ;;
    *)
      echo "seed-content: upload $(basename "$_path") failed HTTP ${_code}" >&2
      printf '%s\n' "$_body" >&2
      case "$_body" in
        *Failed*to*save*the*content*)
          echo "seed-content: hint: Dataverse accepted the upload but could not write to file storage." >&2
          echo "seed-content: hint: With awsS3.enabled, check IAM (s3:PutObject/GetObject/DeleteObject/ListBucket on the bucket), bucket name/region vs values, and that pods were restarted after creating aws-s3-credentials. See docs/DEPLOYMENT.md (S3 troubleshooting)." >&2
          echo "seed-content: hint: Inspect the Dataverse pod logs for AWS SDK errors (AccessDenied, NoSuchBucket, etc.)." >&2
          ;;
      esac
      exit 1
      ;;
  esac
}

# Datasets cannot be published while their host collection is still unpublished (API often returns 403).
publish_dataverse_collection() {
  _alias=$1
  _code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 120 --globoff -X POST \
    -H "X-Dataverse-key: ${TOKEN}" \
    "${API}/dataverses/${_alias}/actions/:publish" || printf '%s' "000")
  case "$_code" in
    200|204)
      echo "seed-content: published dataverse collection '${_alias}'" >&2
      ;;
    409|400)
      echo "seed-content: dataverse '${_alias}' publish returned HTTP ${_code} (often already published); continuing" >&2
      ;;
    *)
      echo "seed-content: WARNING publish dataverse '${_alias}' -> HTTP ${_code} (datasets may fail to publish until collection is released)" >&2
      ;;
  esac
}

publish_dataset() {
  _pid=$1
  _enc=$(encode_pid "$_pid")
  _url="${API}/datasets/:persistentId/actions/:publish?persistentId=${_enc}&type=major"
  _max=${SEED_PUBLISH_MAX_ATTEMPTS:-120}
  _sleep=${SEED_PUBLISH_RETRY_SLEEP:-5}
  _n=0
  while [ "$_n" -lt "$_max" ]; do
    _resp=$(curl -sS --max-time 120 --globoff -X POST \
      -H "X-Dataverse-key: ${TOKEN}" \
      -w "\n%{http_code}" \
      "$_url" || printf '%s\n' "000")
    _code=$(printf '%s\n' "$_resp" | tail -n 1)
    _body=$(printf '%s\n' "$_resp" | sed '$d')

    case "$_code" in
      200|204)
        printf '%s\n' "$_body"
        return 0
        ;;
      403)
        _n=$((_n + 1))
        if [ "$_n" -lt "$_max" ]; then
          echo "seed-content: publish ${_pid} HTTP 403 (often tabular ingest still running); retry ${_n}/${_max} in ${_sleep}s" >&2
          sleep "$_sleep"
        else
          echo "seed-content: publish ${_pid} still HTTP 403 after ${_max} attempts" >&2
          printf '%s\n' "$_body" >&2
          exit 1
        fi
        ;;
      *)
        echo "seed-content: publish ${_pid} failed HTTP ${_code}" >&2
        printf '%s\n' "$_body" >&2
        exit 1
        ;;
    esac
  done
}

seed_dataset_with_files() {
  _marker=$1
  _json=$2
  shift 2

  if contents_has_marker "$CHILD_ALIAS" "$_marker"; then
    echo "seed-content: dataset marker '${_marker}' already present under ${CHILD_ALIAS}; skip" >&2
    return 0
  fi

  echo "seed-content: creating dataset from ${_json}" >&2
  _resp=$(curl -fsS --max-time 120 -X POST \
    -H "X-Dataverse-key: ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary "@${_json}" \
    "${API}/dataverses/${CHILD_ALIAS}/datasets")

  _pid=$(extract_persistent_id "$_resp")
  if [ -z "$_pid" ]; then
    echo "seed-content: could not parse persistentId from create response" >&2
    printf '%s\n' "$_resp" >&2
    exit 1
  fi
  echo "seed-content: dataset created ${_pid}" >&2

  while [ "$#" -ge 3 ]; do
    _f=$1
    _d=$2
    _t=$3
    shift 3
    if [ ! -r "$_f" ]; then
      echo "seed-content: missing file ${_f}" >&2
      exit 1
    fi
    echo "seed-content: upload $(basename "$_f") -> directory ${_d} tabIngest=${_t}" >&2
    upload_file "$_pid" "$_f" "$_d" "$_t"
  done

  echo "seed-content: publishing ${_pid}" >&2
  publish_dataset "$_pid"
  echo "seed-content: published ${_marker}" >&2
}

ensure_subdataverse
publish_dataverse_collection "$CHILD_ALIAS"

# Images: PNG + SVG (different MIME families for smoke tests).
seed_dataset_with_files "DVUP_SEED_A" "${SEED_ROOT}/dataset-images.json" \
  "${SEED_ROOT}/files/1x1.png" "images" "false" \
  "${SEED_ROOT}/files/badge.svg" "images" "false"

# Text + tabular CSV (tabular ingest on for CSV).
seed_dataset_with_files "DVUP_SEED_B" "${SEED_ROOT}/dataset-tabular.json" \
  "${SEED_ROOT}/files/readme.txt" "docs" "false" \
  "${SEED_ROOT}/files/sample.csv" "data" "true"

echo "seed-content: done" >&2
