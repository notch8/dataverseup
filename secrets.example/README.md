# secrets.example

Copy to a gitignored `secrets/` directory at the repo root:

```bash
cp -r secrets.example secrets
```

Files are **development placeholders**. For AWS or any shared host:

- Rotate Payara/admin and DB passwords to match your `.env` (`DATAVERSE_DB_PASSWORD`, `POSTGRES_PASSWORD`, etc.).
- After first successful bootstrap, create a **superuser API token** in the Dataverse UI and store it in **`secrets/api/key`** (single line) so `dev_branding` / `scripts/apply-branding.sh` can run.

Do **not** commit `secrets/`.
