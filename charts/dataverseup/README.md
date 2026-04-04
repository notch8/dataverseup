# dataverseup Helm chart

Deploys **stock Dataverse** (GDCC `gdcc/dataverse` image) on Kubernetes with optional:

- **Persistent** file store and optional **docroot** PVC (branding / logos)
- **Bootstrap** Job (`gdcc/configbaker`)
- **Internal Solr** + **solrInit** initContainer
- **S3** storage driver (AWS-style credentials Secret)
- **Ingress**, **HPA**, **ServiceAccount**

## Quick commands

```bash
helm lint charts/dataverseup
helm template release-name charts/dataverseup -f your-values.yaml
helm upgrade --install release-name charts/dataverseup -n your-namespace -f your-values.yaml
```

## Documentation

See **[docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md)** in this repository for prerequisites, Secret layout, smoke tests, and CI deploy notes.

## Payara init scripts (S3, mail)

S3 and mail relay scripts live only under **`files/init.d/`** as **symbolic links** to the repository root **`init.d/`** (same scripts Docker Compose mounts). Helm follows them when rendering and **`helm package` inlines their contents** into the chart archive, so published charts stay self-contained.

## Configuration

| Key | Purpose |
|-----|---------|
| `image.repository` / `image.tag` | GDCC Dataverse image |
| `extraEnvFrom` / `extraEnvVars` | DB, Solr, URL, JVM — **use Secrets for credentials** |
| `persistence` | RWO PVC for `/data` |
| `internalSolr` + `solrInit` | **Dedicated Solr 9** pod with this release (not a shared cluster Solr). Default **`solrInit.mode: standalone`**; empty **`solrInit.solrHttpBase`** → chart uses the in-release Solr Service. Core **`dataverse`** (Compose uses **`collection1`**). SolrCloud (`mode: cloud`) needs ZK + **full** conf or `solr-conf.tgz`. |
| `bootstrapJob` | First-time `configbaker` bootstrap |
| `ingress` | HTTP routing to Service port 80 |

Solr alignment with Docker Compose (IQSS **`config/`** files, core naming, `solrInit` overrides) is documented in **[docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md)**.
