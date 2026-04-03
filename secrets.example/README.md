# secrets.example

Copy into a gitignored `secrets/` directory at the repo root (nested `secrets/secrets.example/...` is wrong):

```bash
mkdir -p secrets
cp -r secrets.example/. secrets/
```

Files are **development placeholders**. For AWS or any shared host:

- Rotate Payara/admin and DB passwords to match your `.env` (`DATAVERSE_DB_PASSWORD`, `POSTGRES_PASSWORD`, etc.).
- **Local dev / first bootstrap:** `dev_bootstrap` ensures **`secrets/api/bootstrap.env`** exists, then runs configbaker with **`-e /secrets/api/bootstrap.env`**, which records **`API_TOKEN=…`** for the **admin user** created at bootstrap. **`dev_branding`** copies that into **`secrets/api/key`** when `api/key` is empty. Do **not** create **`api/bootstrap.env` as a directory** (it must be a file next to **`api/key`**).
- **Existing database** (bootstrap skipped because metadata blocks already exist): log in as the **admin user** and **create an API token** (Account page → API Token), then put that token on one line in **`secrets/api/key`** yourself—the branding script needs a token from an account with admin privileges, not a separate “superuser token” type in the UI.

Do **not** commit `secrets/`.

**Migrating from an older layout:** if you have **`secrets/bootstrap.env` as a directory** (or a bad path), delete it and ensure you have **`secrets/api/bootstrap.env`** as a **file** (copy from `secrets.example/api/bootstrap.env` or let `dev_bootstrap` create it).
