# DataverseUp

Notch8's **ops wrapper** around stock **[Dataverse](https://dataverse.org/)** (GDCC container images), aligned with the **DataverseUp** plan: pinned versions, compose-first bring-up, and room to grow toward hosted AWS/Kubernetes without forking core.

## Docker Compose stack (`docker-compose.yml`)

This is the operational context that used to live only in compose comments; **read this before editing the file.**

- **Stack:** `docker-compose.yml` is the DataverseUp Docker Compose stack. Extra deployment notes may live in **`docs/DEPLOYMENT.md`** if that file exists in your checkout.
- **Environment:** Compose expects a **`.env`** at the **repo root**. Copy **`.env.example`** to **`.env`** and customize (never commit real secrets).
- **Stack Car / Hyku networking:** The file uses **`networks.default.name: stackcar`** so this project joins the same **`stackcar`** bridge as **`sc proxy up`**. The compose network key is **`default`**, which matches Stack Car's proxy compose file so Docker/Traefik labels stay compatible across apps.
- **Edge proxy:** Install **[Stack Car](https://rubygems.org/gems/stack_car)** (`gem install stack_car`), then run **`sc proxy cert`** and **`sc proxy up`** **separately** from this repo for Traefik on **80/443** (same pattern as **Hyku**). This repository does **not** ship that Traefik container.
- **Browser hostnames:** Use **`*.localhost.direct`** (e.g. `https://localhost.direct/`). Public DNS points those names at `127.0.0.1`; Stack Car supplies TLS for them after **`sc proxy cert`**.
- **Bring-up (bootstrap, branding, seed)** (see **`x-dataverseup-workflow`** in `docker-compose.yml`): a single **`docker compose up -d`** starts the long-running services and, in order, **`dev_bootstrap`** → **`dev_branding`** → **`dev_seed`** (each step **`depends_on`** the previous). You do **not** need a separate **`docker compose run`** for branding or seed on a normal first bring-up. On **first** bootstrap, configbaker writes **`API_TOKEN`** to **`secrets/api/bootstrap.env`**; **`dev_branding`** and **`dev_seed`** refresh **`secrets/api/key`** from that value whenever **`API_TOKEN`** is set (so a stale **`api/key`** after **`down -v`** does not keep an old token). **Re-apply** branding or seed only when you change files or need a retry: **`docker compose run --rm dev_branding`** or **`docker compose run --rm dev_seed`** (both idempotent). After a one-shot container has already exited successfully, a later **`up -d`** may not run it again unless that container was removed (e.g. **`docker compose down`** then **`up`**); use **`run`** in that case.

## Quick start (local / lab)

1. **Prerequisites:** Docker + Docker Compose v2 (`docker compose`), ~4 GB+ RAM (Payara + Solr + Postgres), and **Ruby + RubyGems** for the Stack Car CLI. On Apple Silicon, images use `linux/amd64` (emulation). **Local HTTPS** uses Stack Car's **`sc proxy`** (same pattern as **Hyku** and other Notch8 apps): Traefik on **80/443** with a trusted **`*.localhost.direct`** cert.

2. **Docker network `stackcar` (same as Hyku / other Stack Car apps):** This compose file uses **`networks.default.name: stackcar`** so the project shares the **`stackcar`** bridge with **`sc proxy up`**. Compose network key is **`default`**, matching the proxy compose file, so labels stay compatible. Run **`sc proxy up`** when you want Traefik on 80/443; order relative to **`docker compose up`** is flexible. **`sc proxy down`** removes **`stackcar`** while containers still use it — recreate the stack afterward (e.g. **`docker compose down`** then **`sc proxy up`**, then **`docker compose up -d`**), or bring the proxy back up before starting containers again.

3. **Stack Car: DNS and TLS (Hyku-style):** Defaults use real hostnames under **`*.localhost.direct`** (public DNS resolves them to `127.0.0.1`) so the browser's host matches Traefik rules and TLS works like a normal site. On macOS/Linux we recommend **[Stack Car](https://rubygems.org/gems/stack_car)** for the proxy and dev certificates—the same workflow Hyku documents.

   Install the gem, trust the CA once, then start the proxy (use the **`proxy`** subcommand — not **`sc up`**, which targets other projects and expects a `web` service):

   ```bash
   gem install stack_car
   sc proxy cert   # usually once per machine; re-run when Stack Car's cert bundle changes
   sc proxy up     # Traefik on 80/443, Docker network stackcar
   ```

   **`sc proxy cert`** typically asks for **two** passwords: the first unlocks the **wildcard certificate** archive (where to find that password is documented with Stack Car / your team's Hyku-style setup—often the gem README or internal ops docs). The second is your **local system** password so the CA can be added to your keychain or trust store.

   This repo does not ship Traefik; keep **`sc proxy up`** running while you use **`https://localhost.direct/`**.

4. **Secrets (never commit real `.env` or `secrets/`):**
   ```bash
   cp .env.example .env
   # Defaults target *.localhost.direct; adjust hostname/traefikhost only if you use a different edge proxy.
   mkdir -p secrets
   cp -r secrets.example/. secrets/
   ```
   Use the trailing `/.` and `secrets/` so files land as `secrets/admin/...`, not `secrets/secrets.example/...` (that happens if `secrets` already exists and you run `cp -r secrets.example secrets` without that pattern).

   **`secrets/api/key`** should be a **single line** with only the admin API token (no comments). **`dev_branding` / `dev_seed`** overwrite it from **`secrets/api/bootstrap.env`** when **`API_TOKEN`** is set there after bootstrap.

5. **Start:** **`docker compose up -d`** — brings up Postgres, Solr, Dataverse, etc., then runs **`dev_bootstrap`**, **`dev_branding`**, and **`dev_seed`** in sequence. Re-run **`docker compose run --rm dev_branding`** or **`docker compose run --rm dev_seed`** only when you change **`branding/`** / **`fixtures/seed/`** or need to retry a failed job.

6. **Watch first boot** (can take several minutes; bootstrap → branding → seed run after Dataverse is healthy):
   ```bash
   docker compose logs -f dataverse
   docker compose logs -f dev_bootstrap
   docker compose logs -f dev_branding
   docker compose logs -f dev_seed
   ```

7. **URLs (defaults in `.env.example` with `traefikhost=localhost.direct`):**
   - **HTTPS (via `sc proxy`):** `https://localhost.direct/` and `https://www.localhost.direct/` — Stack Car Traefik terminates TLS; this stack's labels use the **`websecure`** entrypoint only (no Let's Encrypt in compose).
   - **Direct Payara (no proxy):** `http://localhost:8080/`
   - **Not supported:** `https://localhost/` — that host is not part of the `localhost.direct` cert/DNS pattern.
   - **Bootstrap admin** (after `dev_bootstrap` succeeds): username **`dataverseAdmin`**, password **`admin1`** (change before any shared or AWS host; see `docs/DEPLOYMENT.md` if present).
   - **Proxy dashboard:** `https://traefik.localhost.direct/` (from Stack Car Traefik labels).

8. **Branding and API token:** Each **`docker compose up -d`** runs **`dev_branding`** after bootstrap. The entrypoint refreshes **`secrets/api/key`** from **`secrets/api/bootstrap.env`** whenever **`API_TOKEN`** is set, then **`apply-branding.sh`** applies **`branding/branding.env`**. To re-apply branding after you edit that file (without relying on a fresh **`up`**), run **`docker compose run --rm dev_branding`**. If bootstrap did not write **`API_TOKEN`** (e.g. skipped run) and **`api/key`** is wrong or missing, **log in as the admin user** (e.g. **`dataverseAdmin`**) → **Account → API Token**, and put the token on one line in **`secrets/api/key`** (or ensure **`bootstrap.env`** has **`API_TOKEN=`** so the next branding/seed run syncs it). Optional: set **`DATAVERSE_API_TOKEN`** in **`.env`** for compose services that read it (see **`.env.example`**).

9. **Seed demo collection + datasets:** Runs automatically after branding on **`docker compose up -d`** (**`dev_seed`** **`depends_on`** **`dev_branding`**). Compose already waits for **Dataverse** to be healthy and **branding** to finish; the seed entrypoint still **retries** the API for up to **`SEED_WAIT_MAX_SECONDS`** (default **600**, see **`.env.example`**) and can use **`host.docker.internal:8080`** as a fallback. **Dataset publish** retries on **HTTP 403** (tabular **ingest** is asynchronous; defaults **120** attempts × **5**s — **`SEED_PUBLISH_MAX_ATTEMPTS`** / **`SEED_PUBLISH_RETRY_SLEEP`**). To **re-seed** after changing **`fixtures/seed/`**, use **`docker compose run --rm dev_seed`** (do not use **`--no-deps`**). Seeding ensures **`demo`** under **`root`**, **publishes that collection** (datasets cannot be published while the parent dataverse is still a draft), then adds the two demo datasets unless markers **`DVUP_SEED_A`** / **`DVUP_SEED_B`** already exist.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Stack: Postgres, Solr, MinIO (optional), Dataverse, **`dev_bootstrap`**, **`dev_branding`**, **`dev_seed`** (one-shots on **`up`**); `networks.default.name: stackcar` (shared with `sc proxy`) |
| `.env.example` | Version pins and env template — copy to `.env` |
| `secrets.example/` | Payara/Dataverse secret files template — copy to `secrets/` |
| `init.d/` | Payara init scripts (local storage, optional S3/MinIO when env set) |
| `init.d/vendor-solr/` | Vendored `update-fields.sh` / `updateSchemaMDB.sh` (IQSS release assets) for `1002-custom-metadata.sh` |
| `config/schema.xml`, `config/solrconfig.xml` | Vendored from [IQSS Dataverse `develop` `conf/solr/`](https://github.com/IQSS/dataverse/tree/develop/conf/solr); copied into core on Solr start (see `scripts/solr-initdb/`) |
| `config/update-fields.sh` | Same upstream path; use with Dataverse metadata-block tooling when needed |
| `branding/` | Installation branding + static assets |
| `fixtures/seed/` | Dataverse JSON + **`files/`** (PNG, SVG, text, CSV) for **`dev_seed`** |
| `scripts/` | Bootstrap wrapper (`dev-bootstrap-entrypoint.sh`), branding (`apply-branding.sh`, `dev-branding-entrypoint.sh`), seeding (`seed-content.sh`, `dev-seed-entrypoint.sh`) |
| `triggers/` | Postgres notify + optional webhook script (see **`WEBHOOK`** in **`.env.example`**) |
| `docs/DEPLOYMENT.md` | Optional team notes (file not shipped in-repo unless you add it) |

## Version pin

Default image tag in `.env.example` targets **Dataverse 6.10.x** (GDCC tags, e.g. `6.10.1-noble-r0`). Bump only after checking [release notes](https://github.com/IQSS/dataverse/releases) and Solr/schema compatibility.

The compose **Solr** service uses **`solr:9.10.1`** with IQSS **`schema.xml`** and **`solrconfig.xml`** (same repo paths as the application). Refresh those files when you upgrade Dataverse, for example:

```bash
REF=develop  # or a release tag, e.g. v6.10.1
curl -fsSL -o config/schema.xml "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/schema.xml"
curl -fsSL -o config/solrconfig.xml "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/solrconfig.xml"
curl -fsSL -o config/update-fields.sh "https://raw.githubusercontent.com/IQSS/dataverse/${REF}/conf/solr/update-fields.sh"
chmod +x config/update-fields.sh
```

If you previously ran the older **Solr 8** image, remove the compose Solr volume once (`docker volume rm <project>_solr_data`) so the core is recreated under Solr 9, then **reindex** from Dataverse.

## Upstream references

- [IQSS Dataverse `conf/solr/`](https://github.com/IQSS/dataverse/tree/develop/conf/solr) (schema + solrconfig + `update-fields.sh`)
- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html)
- [Application image tags](https://guides.dataverse.org/en/latest/container/app-image.html)
- [GDCC on Docker Hub](https://hub.docker.com/u/gdcc)

## License

Dataverse is licensed by IQSS; container images by their publishers.