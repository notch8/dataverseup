#!/bin/sh
# Apply Dataverse Solr conf ConfigMap to a namespace and optionally restart in-chart workloads so
# init containers / Solr pick up new conf (e.g. after IQSS schema changes or first-time bootstrap).
#
# Requires: kubectl, curl, tar (same as scripts/k8s/ensure-solr-conf-configmap.sh).
#
# Usage (from repo root):
#   ./scripts/solr-init-k8s.sh NAMESPACE HELM_RELEASE_NAME
#
# Env:
#   SOLR_APPLY_CM=true|false              Apply ConfigMap (default: true)
#   SOLR_RESTART_DEPLOYMENTS=true|false   Rollout restart matching Deployments (default: true)
#   CHART_APP_NAME                        app.kubernetes.io/name base label (default: dataverseup)
#   DV_REF, SOLR_DIST_VERSION, CONFIGMAP_NAME — forwarded to ensure-solr-conf-configmap.sh
#   SOLR_ROLLOUT_TIMEOUT                  e.g. 5m (default: 8m)
set -eu

NS="${1:-}"
REL="${2:-}"
if [ -z "$NS" ] || [ -z "$REL" ]; then
  echo "usage: $0 NAMESPACE HELM_RELEASE_NAME" >&2
  echo "  example: $0 demo-dataverseup demo-dataverseup" >&2
  exit 1
fi

SOLR_APPLY_CM="${SOLR_APPLY_CM:-true}"
SOLR_RESTART_DEPLOYMENTS="${SOLR_RESTART_DEPLOYMENTS:-true}"
CHART_APP_NAME="${CHART_APP_NAME:-${HELM_APP_NAME:-dataverseup}}"
SOLR_ROLLOUT_TIMEOUT="${SOLR_ROLLOUT_TIMEOUT:-8m}"

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENSURE="${ROOT}/scripts/k8s/ensure-solr-conf-configmap.sh"

if [ -f "$ENSURE" ] && [ ! -x "$ENSURE" ]; then
  chmod +x "$ENSURE" || true
fi
if [ ! -f "$ENSURE" ]; then
  echo "missing ${ENSURE}" >&2
  exit 1
fi

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required" >&2
  exit 1
}

_truthy() {
  case "$1" in
    1 | true | TRUE | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

if _truthy "$SOLR_APPLY_CM"; then
  echo "=== Solr: applying ConfigMap (${CONFIGMAP_NAME:-dataverse-solr-conf}) ==="
  "$ENSURE" "$NS"
else
  echo "=== Solr: skipping ConfigMap apply (SOLR_APPLY_CM=false) ==="
fi

if ! _truthy "$SOLR_RESTART_DEPLOYMENTS"; then
  echo "=== Solr: skipping rollout restarts (SOLR_RESTART_DEPLOYMENTS=false) ==="
  exit 0
fi

SOLR_LABEL="app.kubernetes.io/instance=${REL},app.kubernetes.io/name=${CHART_APP_NAME}-solr"
APP_LABEL="app.kubernetes.io/instance=${REL},app.kubernetes.io/name=${CHART_APP_NAME}"

restart_labeled() {
  _label="$1"
  _kind="$2"
  kubectl -n "$NS" get deploy -l "$_label" -o name 2>/dev/null | while read -r res; do
    [ -z "$res" ] && continue
    echo "=== Solr: rollout restart $_kind ($res) ==="
    kubectl -n "$NS" rollout restart "$res"
    kubectl -n "$NS" rollout status "$res" --timeout="$SOLR_ROLLOUT_TIMEOUT"
  done
}

# Solr first (Dataverse init container waits for core ping).
restart_labeled "$SOLR_LABEL" "internal Solr"
restart_labeled "$APP_LABEL" "Dataverse"

echo "=== Solr: done ==="
