# Deployment notes (working document)

This file is **intentionally rough**: capture steps, decisions, and surprises while standing up Dataverse for Notch8. Polish into a runbook later.

---

## Ticket summary (internal)

| Field | Value |
|--------|--------|
| **Objective** | Stand up **Dataverse v6.10** on **AWS** by **April 7, 2026** |
| **Bar** | Does **not** need to be production-grade; must **exist and work** |
| **Documentation** | Deployment process + **what we learned** (this file and README pointers) |
| **Business context** | Build capability as a **Dataverse service provider**; diversify beyond **Samvera** |

---

## What this repo is

- **Stock Dataverse** via **GDCC** images (`gdcc/dataverse`, `gdcc/configbaker`), not a fork of the Java app.
- **Knapsack-style overlay:** compose, `init.d/`, Solr schema mount, branding, `secrets/` — upgrade by **bumping image tags** and following upstream release notes.
- Bootstrapped from Notch8’s earlier **`demo-dataverse`** experiment, then cleaned for **no committed `.env`** (use `.env.example` → `.env`) and **`secrets.example/`** → `secrets/`.

---

## Local / lab (Docker Compose)

### Prerequisites

- Docker + Compose v2.
- ~4 GB+ RAM; first boot can take **many minutes** (image pull, Payara, WAR deploy, bootstrap).

### Steps

1. `cp .env.example .env` and edit (at least `useremail` if using ACME on a real DNS name).
2. `cp -r secrets.example secrets` (then replace `secrets/api/key` with a real superuser token **after** first bootstrap, for branding automation).
3. `docker compose up -d`
4. Follow logs: `docker compose logs -f dataverse` and `docker compose logs -f dev_bootstrap`
5. Open `http://localhost/` (Traefik) or `http://localhost:8080/` (direct). Use **`http`** on `:8080`; **HTTPS to the HTTP listener** causes Payara/Grizzly errors.
6. Default bootstrap admin (from configbaker `dev` persona): **`dataverseAdmin`** / **`admin1`** — **change for anything exposed beyond your laptop.**

### Learnings / pitfalls (fill in as you go)

- **Postgres:** This repo uses **`postgres:15-alpine`** (demo used 10.x). If Payara/JDBC misbehaves, confirm JDBC driver / Dataverse 6.10 compatibility and adjust image tag.
- **`init.d/04-setdomain.sh`:** Sets `dataverse.siteUrl` to **`https://` + `hostname`**. For **localhost HTTP** demos, that can be wrong; for **AWS + TLS**, set `hostname` in `.env` to your **public hostname** and terminate TLS at Traefik or ALB.
- **Solr:** Uses **`coronawhy/solr:8.9.0`** with a bind-mounted **`config/schema.xml`**. Upgrading Dataverse may require schema updates — diff against upstream `conf/solr` for that release.
- **`privileged: true`:** Present on Solr/Dataverse in the inherited compose file for local demos. **Revisit before any shared or production environment.**
- **MinIO:** Included for optional S3-style experiments; JVM bucket scripts only run when **`minio_label_1`** etc. are set in `.env`.

---

## AWS (target: April 7)

**Not production-grade** still means: **one working URL**, persistent enough to demo, **documented path**.

### Option A — Single EC2 (fastest path)

1. **Instance:** Linux x86_64, 8 GB+ RAM recommended, security group **22/80/443** (restrict 22 to your IP).
2. Install Docker + Compose (official Docker docs for Amazon Linux / Ubuntu).
3. Clone this repo; copy `.env` and `secrets/`; set **`hostname`** and **`traefikhost`** to the **public DNS** name (or use ALB in front and align `Host` rules).
4. **TLS:** Either Traefik ACME on real DNS (`useremail` in `.env`) or **ALB TLS** → HTTP to instance (adjust Traefik labels / ports accordingly).
5. **Persistence:** By default Compose uses **named volumes**. For a throwaway demo, OK; for “survive stop/start,” document volume backup or attach **EBS** and map volumes (future playbook).
6. **Costs / cleanup:** Tag instance and set calendar reminder to tear down.

### Option B — Kubernetes (EKS)

Not required for the April 7 milestone unless you already run everything on EKS. Notch8’s **`demo-dataverse`** repo contains a **Helm chart** and **`ops/kubernetes-deploy-checklist.md`** — **port or submodule** that content here when Lane B is real.

### What to record after AWS bring-up

- [ ] AMI / OS version and Docker version  
- [ ] Instance size and whether Payara/Solr were stable  
- [ ] **Exact** `.env` knobs that differed from local (hostname, TLS, mail, DOI fake vs real)  
- [ ] Time-to-first-successful-dataset-upload  
- [ ] Anything that differed from [official container docs](https://guides.dataverse.org/en/latest/container/running/index.html)

---

## References

- [Running Dataverse in Docker](https://guides.dataverse.org/en/latest/container/running/index.html)  
- [Demo / evaluation](https://guides.dataverse.org/en/latest/container/running/demo.html)  
- [Production containers (6.8+)](https://guides.dataverse.org/en/latest/container/running/production.html)  
- [Application image tags](https://guides.dataverse.org/en/latest/container/app-image.html)  
- [Hyku Knapsack](https://github.com/samvera-labs/hyku_knapsack) (analogy for keeping overlays thin)

---

## Changelog (optional)

| Date | Author | Note |
|------|--------|------|
| 2026-04-01 | — | Initial template from DataverseUp bootstrap; Postgres bumped to 15 in compose. |
