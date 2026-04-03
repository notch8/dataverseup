# Deployment notes (working document)

Rough notes for standing up Dataverse for Notch8. Extend into a full runbook as you validate each environment.

## Ticket context (internal)

- **Target:** Dataverse **v6.10** on **AWS** by **April 7, 2026** — functional demo, not necessarily production-hardened.
- **Deliverable:** Working deployment **and documented process + learnings** (this file, plus **[HELM.md](HELM.md)** for Kubernetes).

## Docker Compose (local / lab)

See repository **[README.md](../README.md)** — `docker compose up` after `.env` and `secrets/` from examples.

## Kubernetes / Helm

See **[HELM.md](HELM.md)** for chart path, **`bin/helm_deploy`**, Secret layout, Solr ConfigMap, and smoke tests.

### GitHub Actions — Deploy workflow

The **[.github/workflows/deploy.yaml](../.github/workflows/deploy.yaml)** job uses the GitHub **Environment** named by the `environment` workflow input (e.g. `demo`). It must match **`ops/<environment>-deploy.tmpl.yaml`**. The **Prepare kubeconfig and render deploy values** step runs **`envsubst` only for secrets** (`DB_PASSWORD`, `SYSTEM_EMAIL`, `SMTP_PASSWORD`, `SMTP_AUTH`) and **`GITHUB_RUN_ID`**. **Public URLs, ingress, in-cluster Solr/Dataverse Service DNS, S3 bucket name, and Postgres identifiers are plain literals** in that file — edit them there when the environment changes (they must match your Helm release/namespace, e.g. `demo-dataverseup`).

**Secrets (typical, per Environment):** `DB_PASSWORD`, `KUBECONFIG_FILE` (base64), optional mail secrets (`SYSTEM_EMAIL`, `NO_REPLY_EMAIL`, `SMTP_PASSWORD`, `MAIL_SMTP_PASSWORD`).

**Repository or Environment variables (optional):**

| Variable | Purpose | Default if unset |
|----------|---------|------------------|
| `DEPLOY_TOOLBOX_IMAGE` | Job `container` image | `dtzar/helm-kubectl:3.9.4` |
| `HELM_CHART_PATH` | Path passed to `helm` / `bin/helm_deploy` | `./charts/dataverseup` |
| `HELM_APP_NAME` | `app.kubernetes.io/name` for `kubectl rollout status` | `github.event.repository.name` |
| `DEPLOY_ROLLOUT_TIMEOUT` | Rollout wait | `10m` |
| `DEPLOY_BOOTSTRAP_JOB_TIMEOUT` | Bootstrap Job wait | `25m` |

Default Helm **release** and **namespace** are **`<environment>-<repository.name>`** (e.g. `demo-dataverseup`). Override with workflow inputs `k8s_release_name` / `k8s_namespace` when needed.

**Migrating or renaming a release:** Update the literals in **`ops/<environment>-deploy.tmpl.yaml`** (ingress hosts, `dataverse_*` / `DATAVERSE_*` / `hostname`, `solrHttpBase`, `SOLR_*`, `DATAVERSE_URL`, `awsS3.bucketName`, DB names, etc.) so they match the new Helm release and namespace; then align Postgres, S3, TLS, and running workloads.

## Learnings log

| Date | Environment | Note |
|------|-------------|------|
| | | |
