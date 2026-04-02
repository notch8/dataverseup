# Deployment notes (working document)

Rough notes for standing up Dataverse for Notch8. Extend into a full runbook as you validate each environment.

## Ticket context (internal)

- **Target:** Dataverse **v6.10** on **AWS** by **April 7, 2026** — functional demo, not necessarily production-hardened.
- **Deliverable:** Working deployment **and documented process + learnings** (this file, plus **[HELM.md](HELM.md)** for Kubernetes).

## Docker Compose (local / lab)

See repository **[README.md](../README.md)** — `docker compose up` after `.env` and `secrets/` from examples.

## Kubernetes / Helm

See **[HELM.md](HELM.md)** for chart path, **`bin/helm_deploy`**, Secret layout, Solr ConfigMap, and smoke tests.

## Learnings log

| Date | Environment | Note |
|------|-------------|------|
| | | |
