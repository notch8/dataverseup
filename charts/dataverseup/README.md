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

See **[docs/HELM.md](../../docs/HELM.md)** in this repository for prerequisites, Secret layout, and smoke tests.

## Configuration

| Key | Purpose |
|-----|---------|
| `image.repository` / `image.tag` | GDCC Dataverse image |
| `extraEnvFrom` / `extraEnvVars` | DB, Solr, URL, JVM — **use Secrets for credentials** |
| `persistence` | RWO PVC for `/data` |
| `internalSolr` + `solrInit` | In-cluster Solr; requires **full** Solr conf ConfigMap |
| `bootstrapJob` | First-time `configbaker` bootstrap |
| `ingress` | HTTP routing to Service port 80 |

Example skeleton: **`values-examples/internal-solr-starter.yaml`**.
