# DataverseUp

Notch8's **ops wrapper** around stock **[Dataverse](https://dataverse.org/)** (GDCC container images), aligned with the **DataverseUp** plan: pinned versions, compose-first bring-up, and room to grow toward hosted AWS/Kubernetes without forking core.

## Quick start (local / lab)

1. **Prerequisites:** Docker + Docker Compose v2 (`docker compose`), ~4 GB+ RAM (Payara + Solr + Postgres). On Apple Silicon, images use `linux/amd64` (emulation).

2. **Secrets (never commit real `.env` or `secrets/`):**
   ```bash
   cp .env.example .env
   # Edit .env (at least useremail if using ACME on a real hostname)
   cp -r secrets.example secrets
   ```

3. **Start:**
   ```bash
   docker compose up -d
   ```

4. **Watch first boot** (can take several minutes):
   ```bash
   docker compose logs -f dataverse
   docker compose logs -f dev_bootstrap
   ```

5. **URLs (defaults in `.env.example`):**
   - Dataverse (Traefik): `http://localhost/`
   - Direct Payara: `http://localhost:8080/`
   - Bootstrap admin (after `dev_bootstrap` succeeds): **`dataverseAdmin`** / **`admin1`**

6. **Branding (optional):** After creating a **superuser API token** in the UI, put it on one line in `secrets/api/key`, then:
   ```bash
   docker compose run --rm dev_branding
   ```
   Or: `./scripts/dev-up.sh` (brings stack up and re-runs branding).

## Kubernetes (Helm)

```bash
helm lint charts/dataverseup
helm upgrade --install dataverseup charts/dataverseup -n <namespace> -f your-values.yaml
```

Full steps, Secrets, and Solr ConfigMap expectations: **[docs/HELM.md](docs/HELM.md)**. Example values skeleton: **`charts/dataverseup/values-examples/internal-solr-starter.yaml`**.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Stack: Traefik, Postgres, Solr, MinIO (optional), Dataverse, bootstrap, branding |
| `charts/dataverseup/` | **Helm chart** for Kubernetes |
| `.env.example` | Version pins and env template — copy to `.env` |
| `secrets.example/` | Payara/Dataverse secret files template — copy to `secrets/` |
| `init.d/` | Payara init scripts (local storage, optional S3/MinIO when env set) |
| `config/schema.xml` | Solr schema bind-mount (see upstream Solr notes) |
| `branding/` | Installation branding + static assets |
| `scripts/` | Helpers (`apply-branding.sh`, `dev-up.sh`) |
| `docs/HELM.md` | **Helm install / smoke tests / learnings** |
| `docs/DEPLOYMENT.md` | **Working deployment notes (Compose + AWS context)** |

## Version pin

Default image tag in `.env.example` targets **Dataverse 6.10.x** (GDCC tags, e.g. `6.10.1-noble-r0`). Bump only after checking [release notes](https://github.com/IQSS/dataverse/releases) and Solr/schema compatibility.

## Upstream references

- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html)
- [Application image tags](https://guides.dataverse.org/en/latest/container/app-image.html)
- [GDCC on Docker Hub](https://hub.docker.com/u/gdcc)

## License

Dataverse is licensed by IQSS; container images by their publishers.