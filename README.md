# DataverseUp

Notch8's **ops wrapper** around stock **[Dataverse](https://dataverse.org/)** (GDCC container images), aligned with the **DataverseUp** plan: pinned versions, compose-first bring-up, and room to grow toward hosted AWS/Kubernetes without forking core.

## Docker Compose stack (`docker-compose.yml`)

This is the operational context that used to live only in compose comments; **read this before editing the file.**

- **Stack:** `docker-compose.yml` is the DataverseUp Docker Compose stack. Extra deployment notes may live in **`docs/DEPLOYMENT.md`** if that file exists in your checkout.
- **Environment:** Compose expects a **`.env`** at the **repo root**. Copy **`.env.example`** to **`.env`** and customize (never commit real secrets).
- **Stack Car / Hyku networking:** The file uses **`networks.default.name: stackcar`** so this project joins the same **`stackcar`** bridge as **`sc proxy up`**. The compose network key is **`default`**, which matches Stack Car’s proxy compose file so Docker/Traefik labels stay compatible across apps.
- **Edge proxy:** Run **`sc proxy up`** **separately** for Traefik on **80/443**. This repository does **not** ship that Traefik container.
- **Browser hostnames:** Use **`*.localhost.direct`** (e.g. `https://localhost.direct/`). Trust the development CA once per machine with **`sc proxy cert`**.
- **Bring-up + branding workflow** (also in comments and **`x-dataverseup-workflow`** at the top of `docker-compose.yml`):
  ```bash
  docker compose up -d
  docker compose run --rm dev_branding
  ```
  The first line starts the stack; on a new project **`dev_bootstrap`** then an initial **`dev_branding`** run via **`depends_on`**. Run the second line again after you put an API token in **`secrets/api/key`** or edit **`branding/branding.env`** (idempotent).

## Quick start (local / lab)

1. **Prerequisites:** Docker + Docker Compose v2 (`docker compose`), ~4 GB+ RAM (Payara + Solr + Postgres). On Apple Silicon, images use `linux/amd64` (emulation). **Local HTTPS** uses **[Stack Car](https://rubygems.org/gems/stack_car)** `sc proxy` (same pattern as other Notch8 apps): it runs Traefik on **80/443** with a trusted **`*.localhost.direct`** cert.

2. **Docker network `stackcar` (same as Hyku / other Stack Car apps):** This compose file uses **`networks.default.name: stackcar`** so the project shares the **`stackcar`** bridge with **`sc proxy up`**. Compose network key is **`default`**, matching the proxy compose file, so labels stay compatible. Run **`sc proxy up`** when you want Traefik on 80/443; order relative to **`docker compose up`** is flexible. **`sc proxy down`** removes **`stackcar`** while containers still use it — recreate the stack afterward (e.g. **`docker compose down`** then **`sc proxy up`**, then **`docker compose up -d`**), or bring the proxy back up before starting containers again.

3. **Stack Car proxy (TLS on 80/443):** Use the **`proxy`** subcommand — not `sc up`, which targets other projects and expects a `web` service.
   ```bash
   sc proxy cert   # once per machine: installs the localhost.direct CA (password from upstream docs)
   sc proxy up     # Traefik on 80/443 on network stackcar
   ```
   This repo does not ship Traefik; for **`https://localhost.direct`** the proxy must be running.

4. **Secrets (never commit real `.env` or `secrets/`):**
   ```bash
   cp .env.example .env
   # Defaults target *.localhost.direct; adjust hostname/traefikhost only if you use a different edge proxy.
   mkdir -p secrets
   cp -r secrets.example/. secrets/
   ```
   Use the trailing `/.` and `secrets/` so files land as `secrets/admin/...`, not `secrets/secrets.example/...` (that happens if `secrets` already exists and you run `cp -r secrets.example secrets` without that pattern).

5. **Start (compose workflow — same as `docker-compose.yml` header):**
   ```bash
   docker compose up -d
   docker compose run --rm dev_branding
   ```
   Re-run only the second command when you need to re-apply branding; see **Docker Compose stack** above for details.

6. **Watch first boot** (can take several minutes):
   ```bash
   docker compose logs -f dataverse
   docker compose logs -f dev_bootstrap
   ```

7. **URLs (defaults in `.env.example` with `traefikhost=localhost.direct`):**
   - **HTTPS (via `sc proxy`):** `https://localhost.direct/` and `https://www.localhost.direct/` — Stack Car Traefik terminates TLS; this stack's labels use the **`websecure`** entrypoint only (no Let's Encrypt in compose).
   - **Direct Payara (no proxy):** `http://localhost:8080/`
   - **Not supported:** `https://localhost/` — that host is not part of the `localhost.direct` cert/DNS pattern.
   - **Bootstrap admin** (after `dev_bootstrap` succeeds): username **`dataverseAdmin`**, password **`admin1`** (change before any shared or AWS host; see `docs/DEPLOYMENT.md` if present).
   - **Proxy dashboard:** `https://traefik.localhost.direct/` (from Stack Car Traefik labels).

8. **Branding (optional):** Log in as that admin user, open your **account** page from the user menu in the header, and create an **API token** there (the bootstrap admin is a superuser, so that token has the rights branding scripts need). Put the token on one line in **`secrets/api/key`**, then run the second command from step **5** (`docker compose run --rm dev_branding`).

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Stack: Postgres, Solr, MinIO (optional), Dataverse, bootstrap, branding; `networks.default.name: stackcar` (shared with `sc proxy`) |
| `.env.example` | Version pins and env template — copy to `.env` |
| `secrets.example/` | Payara/Dataverse secret files template — copy to `secrets/` |
| `init.d/` | Payara init scripts (local storage, optional S3/MinIO when env set) |
| `config/schema.xml` | Solr schema bind-mount (see upstream Solr notes) |
| `branding/` | Installation branding + static assets |
| `scripts/` | Helpers (`apply-branding.sh`; invoked by `dev_branding` in compose) |
| `docs/DEPLOYMENT.md` | **Working deployment notes + learnings** |

## Version pin

Default image tag in `.env.example` targets **Dataverse 6.10.x** (GDCC tags, e.g. `6.10.1-noble-r0`). Bump only after checking [release notes](https://github.com/IQSS/dataverse/releases) and Solr/schema compatibility.

## Upstream references

- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html)
- [Application image tags](https://guides.dataverse.org/en/latest/container/app-image.html)
- [GDCC on Docker Hub](https://hub.docker.com/u/gdcc)

## License

Dataverse is licensed by IQSS; container images by their publishers.