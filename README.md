# DataverseUp

Notch8's **ops wrapper** around stock **[Dataverse](https://dataverse.org/)** (GDCC container images), aligned with the **DataverseUp** plan: pinned versions, compose-first bring-up, and room to grow toward hosted AWS/Kubernetes without forking core.

## Quick start (local / lab)

1. **Prerequisites:** Docker + Docker Compose v2 (`docker compose`), ~4 GB+ RAM (Payara + Solr + Postgres), and **Ruby + RubyGems** for [Stack Car](https://rubygems.org/gems/stack_car) (edge TLS — same **`*.localhost.direct`** pattern as Hyku). On Apple Silicon, images use `linux/amd64` (emulation).

2. **Edge proxy (Stack Car):** This repo does **not** ship Traefik; labels target the shared Docker network **`stackcar`** (same as `sc proxy up`). Install the gem, trust the CA once, then keep the proxy running while you use the site:

   ```bash
   gem install stack_car
   sc proxy cert   # usually once per machine
   sc proxy up     # Traefik on 80/443, network stackcar
   ```

3. **Secrets (never commit real `.env` or `secrets/`):**
   ```bash
   cp .env.example .env
   # Defaults use *.localhost.direct; adjust hostname/traefikhost only if your edge differs.
   mkdir -p secrets
   cp -r secrets.example/. secrets/
   ```
   Use `secrets.example/.` → `secrets/` so files land as `secrets/admin/...`, not nested under `secrets/secrets.example/`.

4. **Start:** A single `docker compose up -d` brings up Postgres, Solr, MinIO (optional), Dataverse, then runs **`dev_bootstrap`** → **`dev_branding`** → **`dev_seed`** in order (see `x-dataverseup-workflow` in `docker-compose.yml`).

5. **Watch first boot** (can take several minutes):
   ```bash
   docker compose logs -f dataverse
   docker compose logs -f dev_bootstrap
   docker compose logs -f dev_branding
   docker compose logs -f dev_seed
   ```

6. **URLs (defaults in `.env.example`, `traefikhost=localhost.direct`):**
   - Dataverse (via Stack Car): `https://localhost.direct/` and `https://www.localhost.direct/`
   - Direct Payara: `http://localhost:8080/`
   - Traefik dashboard (Stack Car): `https://traefik.localhost.direct/`
   - Bootstrap admin (after `dev_bootstrap` succeeds): **`dataverseAdmin`** / **`admin1`** (change before any shared or AWS host; see `docs/DEPLOYMENT.md` when you maintain it)

7. **Branding / seed (re-runs):** On first boot, configbaker writes **`API_TOKEN`** to **`secrets/api/bootstrap.env`**; **`dev_branding`** / **`dev_seed`** refresh **`secrets/api/key`** from that when **`API_TOKEN`** is set. To re-apply after you change **`branding/`** or **`fixtures/seed/`**:
   ```bash
   docker compose run --rm dev_branding
   docker compose run --rm dev_seed
   ```
   If you need a manual token, put it on one line in **`secrets/api/key`** (superuser token from the UI), then run **`dev_branding`** again.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Stack: Postgres, Solr, MinIO (optional), Dataverse, bootstrap, branding, seed; Traefik labels + **`networks.default.name: stackcar`** (Stack Car proxy) |
| `.env.example` | Version pins and env template — copy to `.env` |
| `secrets.example/` | Payara/Dataverse secret files template — copy to **`secrets/`** (see Quick start) |
| `init.d/` | Payara init scripts (local storage, optional S3/MinIO when env set) |
| `init.d/vendor-solr/` | Vendored Solr helpers for `1002-custom-metadata.sh` |
| `config/schema.xml`, `config/solrconfig.xml` | Solr conf bind-mounts / upstream copies (see `scripts/solr-initdb/`) |
| `config/update-fields.sh` | Upstream metadata-block tooling helper |
| `branding/` | Installation branding + static assets |
| `fixtures/seed/` | JSON + files for **`dev_seed`** |
| `scripts/` | Bootstrap, branding, seed entrypoints, `apply-branding.sh`, `solr-initdb/` |
| `triggers/` | Postgres notify + optional webhook script (see **`WEBHOOK`** in `.env.example`) |
| `docs/DEPLOYMENT.md` | **Working deployment notes + learnings** (add in-repo when you maintain runbooks) |

## Version pin

Default image tag in `.env.example` targets **Dataverse 6.10.x** (GDCC tags, e.g. `6.10.1-noble-r0`). Bump only after checking [release notes](https://github.com/IQSS/dataverse/releases) and Solr/schema compatibility.

Compose uses **`solr:9.10.1`** with IQSS **`schema.xml`** / **`solrconfig.xml`** vendored under **`config/`**. Refresh those when you upgrade Dataverse:

```bash
REF=develop  # or a release tag, e.g. v6.10.1
curl -fsSL -o config/schema.xml "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/schema.xml"
curl -fsSL -o config/solrconfig.xml "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/solrconfig.xml"
curl -fsSL -o config/update-fields.sh "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/update-fields.sh"
chmod +x config/update-fields.sh
```

If you previously ran Solr 8, remove the compose Solr volume once so the core is recreated under Solr 9, then reindex from Dataverse.

## Upstream references

- [IQSS Dataverse `conf/solr/`](https://github.com/IQSS/dataverse/tree/develop/conf/solr) (schema + solrconfig + `update-fields.sh`)
- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html)
- [Application image tags](https://guides.dataverse.org/en/latest/container/app-image.html)
- [GDCC on Docker Hub](https://hub.docker.com/u/gdcc)

## License

Dataverse is licensed by IQSS; container images by their publishers.
