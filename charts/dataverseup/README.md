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

## Payara init scripts (S3, mail)

`files/006-s3-aws-storage.sh` and `files/010-mailrelay-set.sh` are **symbolic links** to the same scripts in the repository root **`init.d/`** (used by Docker Compose). Helm follows them when rendering and **`helm package` inlines their contents** into the chart archive, so published charts stay self-contained.

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
