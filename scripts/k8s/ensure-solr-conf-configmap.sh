#!/bin/sh
# Build IQSS Dataverse Solr config (same layout as test-k3d-deploy/k3d/install.sh) and apply ConfigMap
# <CONFIGMAP_NAME> with key solr-conf.tgz — required by the chart's internal Solr init container.
#
# Uses curl + tar only (no Docker). Run after kubectl context points at the target cluster.
#
# Usage: ./scripts/k8s/ensure-solr-conf-configmap.sh NAMESPACE
# Env:
#   DV_REF              IQSS Dataverse tag (default: v6.10.1)
#   SOLR_DIST_VERSION   Apache Solr release for _default configset extras (default: 9.10.1)
#   CONFIGMAP_NAME      (default: dataverse-solr-conf)
set -eu

NAMESPACE="${1:-}"
if [ -z "$NAMESPACE" ]; then
  echo "usage: $0 NAMESPACE" >&2
  exit 1
fi

DV_REF="${DV_REF:-v6.10.1}"
SOLR_DIST_VERSION="${SOLR_DIST_VERSION:-9.10.1}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-dataverse-solr-conf}"

for cmd in kubectl curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
done

TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Fetching IQSS Dataverse ${DV_REF} (conf/solr) ..."
curl -fsSL "https://codeload.github.com/IQSS/dataverse/tar.gz/${DV_REF}" -o "$TMP/dv.tgz"
tar -xzf "$TMP/dv.tgz" -C "$TMP"
TOP="$(find "$TMP" -maxdepth 1 -type d -name 'dataverse-*' | head -1)"
if [ -z "$TOP" ] || [ ! -d "$TOP/conf/solr" ]; then
  echo "Could not find dataverse-*/conf/solr in archive (try DV_REF=develop or a valid tag)." >&2
  exit 1
fi

STAGE="${TMP}/solr-stage"
mkdir -p "${STAGE}"
cp -a "${TOP}/conf/solr/." "${STAGE}/"

SPREFIX="solr-${SOLR_DIST_VERSION}/server/solr/configsets/_default/conf"
SOLR_URL="https://archive.apache.org/dist/solr/solr/${SOLR_DIST_VERSION}/solr-${SOLR_DIST_VERSION}.tgz"
echo "Fetching Solr ${SOLR_DIST_VERSION} _default conf companions from ${SOLR_URL} ..."
curl -fsSL "${SOLR_URL}" -o "$TMP/apache-solr.tgz"
tar -xzf "$TMP/apache-solr.tgz" -C "$TMP" \
  "${SPREFIX}/lang" \
  "${SPREFIX}/protwords.txt" \
  "${SPREFIX}/stopwords.txt" \
  "${SPREFIX}/synonyms.txt"

CONFROOT="${TMP}/${SPREFIX}"
cp -a "${CONFROOT}/lang" "${STAGE}/"
for f in protwords.txt stopwords.txt synonyms.txt; do
  cp -a "${CONFROOT}/${f}" "${STAGE}/${f}"
done

SOLR_TGZ="${TMP}/solr-conf.tgz"
tar -czf "${SOLR_TGZ}" -C "${STAGE}" .
echo "Packaged Solr conf ($(du -h "${SOLR_TGZ}" | cut -f1)) → ConfigMap ${CONFIGMAP_NAME} key solr-conf.tgz"

kubectl -n "${NAMESPACE}" create configmap "${CONFIGMAP_NAME}" \
  --from-file=solr-conf.tgz="${SOLR_TGZ}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applied ConfigMap ${CONFIGMAP_NAME} in namespace ${NAMESPACE}"
