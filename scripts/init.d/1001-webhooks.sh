#!/bin/bash

# Running python script to invoke webhooks
if [ "${WEBHOOK}" ]; then
    PGPASSWORD=${POSTGRES_PASSWORD};export PGPASSWORD
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DATABASE}" -h "${POSTGRES_SERVER}" -f "${HOME_DIR}/triggers/external-service.sql"
    python3 "${WEBHOOK}" &
    echo "Setting webhook on ${WEBHOOK}" >> /tmp/status.log
fi
