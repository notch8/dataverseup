#!/usr/bin/env bash
# After precreate-core, copy IQSS upstream schema + solrconfig into the core (solr-owned tree).
# Bind-mounting those files directly under collection1 often leaves root-owned parents and breaks core.properties.
set -euo pipefail
CORE=collection1
coredir="/var/solr/data/${CORE}"
UPSTREAM="/opt/upstream-solr-conf"

if [[ ! -f "${coredir}/core.properties" ]]; then
  /opt/solr/docker/scripts/precreate-core "${CORE}"
fi

cp -a "${UPSTREAM}/schema.xml" "${coredir}/conf/schema.xml"
cp -a "${UPSTREAM}/solrconfig.xml" "${coredir}/conf/solrconfig.xml"
