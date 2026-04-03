# secrets.example

Copy into a gitignored `secrets/` directory at the repo root (nested `secrets/secrets.example/...` is wrong):

```bash
mkdir -p secrets
cp -r secrets.example/. secrets/
```

Files are **development placeholders**. For AWS or any shared host:

- Rotate Payara/admin and DB passwords to match your `.env` (`DATAVERSE_DB_PASSWORD`, `POSTGRES_PASSWORD`, etc.).
- After first successful bootstrap, log in as the admin user, open the **account** page from the user menu, and create an **API token**. That user is a superuser, so the token is sufficient for **`secrets/api/key`** (single line) and `dev_branding` / `scripts/apply-branding.sh`.

Do **not** commit `secrets/`.
