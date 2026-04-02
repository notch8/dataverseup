# Helm deployment (DataverseUp chart)

This document describes how to install the **`dataverseup`** Helm chart from this repository. It is written as **working notes** you can extend into a full runbook after the first successful deploy.

**Prerequisites:** Helm 3, a Kubernetes cluster, `kubectl` configured, a **PostgreSQL** database reachable from the cluster (in-cluster or managed), and a **StorageClass** for any PVCs you enable.

**Chart path:** `charts/dataverseup`

## `bin/helm_deploy` (recommended wrapper)

From the **repository root**, installs or upgrades the chart with **`--install`**, **`--atomic`**, **`--create-namespace`**, and a default **`--timeout 30m0s`** (Payara first boot is slow).

```text
./bin/helm_deploy RELEASE_NAME NAMESPACE
```

Pass extra Helm flags with **`HELM_EXTRA_ARGS`** (values file, longer timeout, etc.). If you pass a **second `--timeout`** in `HELM_EXTRA_ARGS`, it overrides the default (Helm uses the last value).

```bash
HELM_EXTRA_ARGS="--values ./your-values.yaml --wait --timeout 45m0s" ./bin/helm_deploy my-release my-namespace
```

## What the chart deploys

- **Dataverse** (`gdcc/dataverse`) — Payara on port **8080**; Service may expose **80** → target **8080** for Ingress compatibility.
- **Optional bootstrap Job** (`gdcc/configbaker`) — `bootstrap.sh dev` (FAKE DOI, `dataverseAdmin`, etc.). Usually a **Helm post-install hook** (`bootstrapJob.helmHook: true`).
- **Optional in-cluster Solr** (`internalSolr`) — single-node Solr with core `dataverse`, plus **`solrInit`** initContainer to wait for Solr / upload config (mode **cloud** or **standalone**).
- **Optional S3** — `awsS3.enabled` mounts AWS credentials and ships the S3 init script.

The chart does **not** install PostgreSQL by default. Supply DB settings with **`extraEnvVars`** and/or **`extraEnvFrom`** (recommended: Kubernetes **Secret** for passwords).

## Install flow (recommended order)

1. **Create namespace**  
   `kubectl create namespace <ns>`

2. **Database**  
   Provision Postgres and a database/user for Dataverse. Note the service DNS name inside the cluster (e.g. `postgres.<ns>.svc.cluster.local`).

3. **Solr configuration ConfigMap** (if using `solrInit` / `internalSolr`)  
   Dataverse needs a **full** Solr configuration directory for its version — not `schema.xml` alone. Build a ConfigMap whose keys are the files under that conf directory (or a single `solr-conf.tgz` as produced by your packaging process). See [Solr prerequisites](https://guides.dataverse.org/en/latest/installation/prerequisites.html#solr).

4. **Application Secret** (example name `dataverse-app-env`)  
   Prefer `stringData` for passwords. Include at least the variables the GDCC image expects for JDBC and Solr (mirror what you use in Docker Compose `.env`). Typical keys include:

   - `DATAVERSE_DB_HOST`, `DATAVERSE_DB_USER`, `DATAVERSE_DB_PASSWORD`, `DATAVERSE_DB_NAME`
   - `POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `PGPASSWORD`
   - Solr: `SOLR_LOCATION` or `DATAVERSE_SOLR_HOST` / `DATAVERSE_SOLR_PORT` / `DATAVERSE_SOLR_CORE` (match your Solr deployment)
   - Public URL / hostname: `DATAVERSE_URL`, `hostname`, `DATAVERSE_SERVICE_HOST` (used by init scripts and UI)
   - Optional: `DATAVERSE_PID_*` for FAKE DOI (see default chart comments and [container demo docs](https://guides.dataverse.org/en/latest/container/running/demo.html))

5. **Values file**  
   Start from `charts/dataverseup/values.yaml` and override with a small values file of your own. At minimum for a first install:

   - `persistence.enabled: true` (file store)
   - `extraEnvFrom` pointing at your Secret
   - If using bundled Solr: `internalSolr.enabled`, `solrInit.enabled`, `solrInit.mode: standalone`, `solrInit.confConfigMap`, `solrInit.solrHttpBase` matching the in-chart Solr Service
   - `bootstrapJob.enabled: true` for first-time seeding

6. **Lint and render**

   ```bash
   helm lint charts/dataverseup -f your-values.yaml
   helm template dataverseup charts/dataverseup -f your-values.yaml > /tmp/manifests.yaml
   ```

7. **Install**

   Using the wrapper (from repo root):

   ```bash
   HELM_EXTRA_ARGS="--values ./your-values.yaml --wait" ./bin/helm_deploy <release> <namespace>
   ```

   Raw Helm (equivalent shape):

   ```bash
   helm upgrade --install <release> charts/dataverseup -n <ns> -f your-values.yaml --wait --timeout 45m
   ```

8. **Smoke tests**

   - `kubectl get pods -n <ns>`
   - Bootstrap job logs (if enabled): `kubectl logs -n <ns> job/...-bootstrap`
   - API: port-forward or Ingress → `GET /api/info/version` should return **200**
   - UI login (default bootstrap admin from configbaker **dev** profile — **change** before any shared environment)

9. **Helm test** (optional)

   ```bash
   helm test <release> -n <ns>
   ```

## Ingress and TLS

Set `ingress.enabled: true`, `ingress.className` to your controller (e.g. `nginx`, `traefik`), and hosts/TLS to match your DNS. Payara serves **HTTP** on 8080; the Service fronts it on port **80** so Ingress backends stay HTTP.

If you terminate TLS or expose the app on a **non-default host port**, keep **`DATAVERSE_URL`** and related hostname settings aligned with the URL users and the app use.

## Payara init scripts (DRY with Compose)

The chart embeds the S3 and mail relay scripts from **`init.d/`** at the repo root via symlinks under `charts/dataverseup/files/`. Edit **`init.d/006-s3-aws-storage.sh`** or **`init.d/010-mailrelay-set.sh`** once; both Compose mounts and Helm ConfigMaps stay aligned. `helm package` resolves symlink content into the tarball.

## S3 file storage

1. Create a Secret in the release namespace with keys matching `awsS3.secretKeys` (default: `credentials`, `config`) — same shape as AWS CLI config files.
2. Set `awsS3.enabled: true`, `awsS3.existingSecret`, `bucketName`, `endpointUrl`, `region`, `profile`.

## Upgrades

- Bump `image.tag` / `Chart.appVersion` together with [Dataverse release notes](https://github.com/IQSS/dataverse/releases).
- Reconcile Solr conf ConfigMap when Solr schema changes.
- If `bootstrapJob.helmHook` is **true**, the bootstrap Job runs on **post-install only**, not on every upgrade (by design).

## Learnings log

Append rows as you go (cluster type, storage class, what broke, what fixed it):

| Date | Cluster | Note |
|------|---------|------|
| | | |

## References

- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html) (conceptual parity with container env)
- [Application image](https://guides.dataverse.org/en/latest/container/app-image.html)
- [Solr prerequisites](https://guides.dataverse.org/en/latest/installation/prerequisites.html#solr)
