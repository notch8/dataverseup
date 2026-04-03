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
- **Optional bootstrap Job** (`gdcc/configbaker`) — usually a **Helm post-install hook** (`bootstrapJob.helmHook: true`). **`bootstrapJob.mode: oneShot`** runs **`bootstrapJob.command`** only (default: `bootstrap.sh dev` — FAKE DOI, `dataverseAdmin`, etc.). **`bootstrapJob.mode: compose`** mirrors local Docker Compose: wait for the API, run configbaker with a writable token file on `emptyDir`, then **`apply-branding.sh`** and **`seed-content.sh`** (fixtures baked into a ConfigMap). Tune waits with **`bootstrapJob.compose`** and allow a longer **`bootstrapJob.timeout`** when seeding.
- **Optional dedicated Solr** (`internalSolr`) — a **new** Solr Deployment/Service in the **same release and namespace** as Dataverse (not wiring into someone else’s shared “cluster Solr”). Default **`solrInit.mode`** is **`standalone`**: the Dataverse pod waits for that Solr core before starting. Use **`solrInit.mode: cloud`** only when Dataverse talks to **SolrCloud + ZooKeeper** you operate separately.
- **Optional S3** — `awsS3.enabled` mounts AWS credentials and ships the S3 init script.

### Branding (navbar logo + Admin API settings)

1. **Navbar SVG** — Enable **`brandingNavbarLogos.enabled`** so an init container copies **`branding/docroot/logos/navbar/logo.svg`** from the chart onto **`/dv/docroot/logos/navbar/logo.svg`** (needs **`docrootPersistence`** or the chart’s emptyDir docroot fallback). Match **`LOGO_CUSTOMIZATION_FILE`** in **`branding/branding.env`** to the web path (e.g. `/logos/navbar/logo.svg`).

2. **Admin settings** (installation name, footer, optional custom header/footer CSS paths) — Edit **`branding/branding.env`** in the repo. The chart embeds it in the **`…-bootstrap-chain`** ConfigMap when **`bootstrapJob.mode: compose`**. The post-install Job runs **`apply-branding.sh`**, which PUTs those settings via the Dataverse Admin API using the admin token from configbaker.

3. **Custom HTML/CSS files** — Add them under **`branding/docroot/branding/`** in the repo, set **`HEADER_CUSTOMIZATION_FILE`**, etc. in **`branding.env`** to **`/dv/docroot/branding/...`**, and ship those files into the pod (extra **`volumeMounts`** / **`configMap`** or bake into an image). The stock chart does not mount the whole **`branding/docroot/branding/`** tree on the main Deployment; compose only ships **`branding.env`** and the logo via **`brandingNavbarLogos`**.

4. **After `helm upgrade`** — The post-install hook does **not** re-run. To re-apply branding, use **`bootstrapJob.compose.postUpgradeBrandingSeedJob`** with a Secret holding **`DATAVERSE_API_TOKEN`**, or run **`scripts/apply-branding.sh`** locally/cron with **`DATAVERSE_INTERNAL_URL`** and a token.

The chart does **not** install PostgreSQL by default. Supply DB settings with **`extraEnvVars`** and/or **`extraEnvFrom`** (recommended: Kubernetes **Secret** for passwords).

### Recommended Solr layout: new instance with this deploy

Enable **`internalSolr.enabled`**, **`solrInit.enabled`**, keep **`solrInit.mode: standalone`**, and supply **`solrInit.confConfigMap`**. Leave **`solrInit.solrHttpBase` empty** — the chart sets the Solr admin URL to the in-release Service (`http://<release>-solr.<namespace>.svc.cluster.local:8983`). Point your app Secret at that same host/port and core (see table below). You do **not** need an existing Solr installation in the cluster.

## Docker Compose vs Helm (Solr)

Local **`docker-compose.yml`** and this chart both target **official Solr 9** (`solr:9.10.1`) and IQSS **`conf/solr`** files vendored under repo **`config/`** (refresh from IQSS `develop` or a release tag as in the root **`README.md`**).

| | Docker Compose | Helm (`internalSolr` + `solrInit`) |
|---|----------------|-----------------------------------|
| Solr image pin | `solr:9.10.1` | `internalSolr.image` / `solrInit.image` default `solr:9.10.1` |
| Default core name | **`collection1`** (see `scripts/solr-initdb/01-ensure-core.sh`) | **`dataverse`** (`solr-precreate` in `internal-solr-deployment.yaml`) |
| App Solr address | `SOLR_LOCATION=solr:8983` (host:port) | With **`internalSolr.enabled`**, the chart sets **`DATAVERSE_SOLR_HOST`**, **`DATAVERSE_SOLR_PORT`**, **`DATAVERSE_SOLR_CORE`**, **`SOLR_SERVICE_*`**, and **`SOLR_LOCATION`** to the in-release Solr Service and **`solrInit.collection`** (default **`dataverse`**). The GDCC `ct` profile otherwise defaults to host **`solr`** and core **`collection1`**, which breaks Kubernetes installs if unset. |

Compose only copies **`schema.xml`** and **`solrconfig.xml`** into the core after precreate. **SolrCloud** (`solrInit.mode: cloud`) still needs a **full** conf tree or **`solr-conf.tgz`** (including `lang/`, `stopwords.txt`, etc.) for `solr zk upconfig` — see [Solr prerequisites](https://guides.dataverse.org/en/latest/installation/prerequisites.html#solr).

### `solrInit` image: standalone (default) vs SolrCloud

- **Standalone** (default, with **`internalSolr`**): the initContainer **waits** for `/solr/<core>/admin/ping` via `curl`; the default **`solr:9.10.1`** image is sufficient. This matches launching a **solo Solr** with the chart instead of consuming a shared cluster Solr Service.
- **Cloud / ZooKeeper** (optional): set **`solrInit.mode: cloud`** and **`solrInit.zkConnect`** when Dataverse uses **SolrCloud** you run elsewhere. The same container runs **`solr zk upconfig`**; use a Solr **major** compatible with that cluster. Override **`solrInit.image`**, **`solrInit.solrBin`**, and **`solrInit.securityContext`** if you use a vendor image (e.g. legacy Bitnami).

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
   - If using dedicated in-chart Solr: `internalSolr.enabled`, `solrInit.enabled`, `solrInit.confConfigMap`, `solrInit.mode: standalone` (default). Omit `solrInit.solrHttpBase` to use the auto-derived in-release Solr Service URL
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

Set **`initdFromChart.enabled: true`** in values to include **all** `files/init.d/*.sh` in the same ConfigMap (compose parity with mounting `./init.d`). Keep **`INIT_SCRIPTS_FOLDER`** (or the image default) pointed at **`/opt/payara/init.d`**. Review MinIO- and triggers-specific scripts before enabling in a cluster that does not mount those paths.

## S3 file storage

1. Set `awsS3.enabled: true`, `awsS3.existingSecret`, `bucketName`, `endpointUrl`, `region`, and `profile` in values. The IAM principal behind the Secret needs S3 access to that bucket.

2. Create a **generic** Secret in the **same namespace** as the Helm release, **before** pods that mount it start. Key names must match `awsS3.secretKeys` (defaults below): the values are the **raw file contents** of `~/.aws/credentials` and `~/.aws/config`.

   - `credentials` — ini format; the profile block header (e.g. `[default]` or `[my-profile]`) must match **`awsS3.profile`**.
   - `config` — ini format; for `profile: default` use `[default]` with `region = ...`. For a named profile use `[profile my-profile]` and the same region as `awsS3.region` unless you know you need otherwise.

3. **Examples** (replace `NAMESPACE`, keys, region, and secret name if you changed `existingSecret`):

   ```sh
   NS=NAMESPACE
   kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

   kubectl -n "$NS" create secret generic aws-s3-credentials \
     --from-file=credentials="$HOME/.aws/credentials" \
     --from-file=config="$HOME/.aws/config" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

   Inline `[default]` user (no local files):

   ```sh
   kubectl -n "$NS" create secret generic aws-s3-credentials \
     --from-literal=credentials="[default]
   aws_access_key_id = AKIA...
   aws_secret_access_key = ...
   " \
     --from-literal=config="[default]
   region = us-west-2
   " \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

   If you use **temporary credentials** (assumed role / STS), add a line to the credentials profile: `aws_session_token = ...`. Rotate before expiry or automate renewal.

4. After creating or updating the Secret, **restart** the Dataverse Deployment (or delete its pods) so the volume is remounted. The chart sets `AWS_SHARED_CREDENTIALS_FILE` and `AWS_CONFIG_FILE` to the mounted paths.

**Note:** The Java AWS SDK inside the app may not perform the same **assume-role chaining** as the AWS CLI from a complex `config` file. Prefer putting **direct** user keys or **already-assumed** temporary keys in the Secret for the app, or use EKS **IRSA** (service account + role) instead of long-lived keys if your platform supports it.

## Upgrades

- Bump `image.tag` / `Chart.appVersion` together with [Dataverse release notes](https://github.com/IQSS/dataverse/releases).
- Reconcile Solr conf ConfigMap when Solr schema changes.
- When upgrading **internal Solr** across a **major Solr version** (e.g. 8 → 9), use a **fresh** Solr data volume (new PVC or wipe `internalSolr` persistence) so cores are recreated; same idea as Compose (see root **`README.md`**).
- After bumping **`solrInit`** / **`internalSolr`** images, re-test **SolrCloud** installs (`solr zk` + collection create) in a non-production cluster if you use `solrInit.mode: cloud`.
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
