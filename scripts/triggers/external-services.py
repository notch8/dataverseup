# DANS-KNAW External services webhook
# Plug in services here for processing and archiving of published datasets.
import json
import os
import select
from urllib.parse import quote

import psycopg2
import requests
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

REQUEST_TIMEOUT = (5.0, 120.0)


def _env_truthy(name: str) -> bool:
    v = os.environ.get(name, "").strip().lower()
    return v in ("1", "true", "yes", "on")


WEBHOOKDEBUG = _env_truthy("WEBHOOKDEBUG")

conn = psycopg2.connect(
    host=os.environ["DATAVERSE_DB_HOST"],
    dbname=os.environ["DATAVERSE_DB_NAME"],
    user=os.environ["DATAVERSE_DB_USER"],
    password=os.environ["DATAVERSE_DB_PASSWORD"],
)
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
cur = conn.cursor()

cur.execute("LISTEN released_versionstate_datasetversion;")
print("Waiting for notifications on channel 'released_versionstate_datasetversion'")

while True:
    if select.select([conn], [], [], 10) == ([], [], []):
        pass
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            print(f"Got NOTIFY: {notify.channel} - {notify.payload}")
            try:
                json_data = json.loads(notify.payload)
            except json.JSONDecodeError as e:
                print(f"external-services: invalid JSON payload: {e}", flush=True)
                continue
            data = json_data.get("data")
            if not data or not isinstance(data, list):
                print("external-services: missing or empty 'data' in payload", flush=True)
                continue
            row = data[0]
            if not isinstance(row, dict):
                print("external-services: first data row is not an object", flush=True)
                continue
            try:
                protocol = row["protocol"]
                authority = row["authority"]
                identifier = row["identifier"]
            except KeyError as e:
                print(f"external-services: missing field in payload row: {e}", flush=True)
                continue

            if WEBHOOKDEBUG:
                print(data)

            pid = f"{protocol}:{authority}/{identifier}"
            q = quote(pid, safe="")
            base = os.environ["DATAVERSE_URL"].lstrip("/")
            url = f"http://{base}/api/datasets/export?exporter=dataverse_json&persistentId={q}"
            if WEBHOOKDEBUG:
                print(url)
            try:
                response = requests.get(url, timeout=REQUEST_TIMEOUT)
            except requests.RequestException as e:
                print(f"external-services: request failed: {e}", flush=True)
                continue
            if not response.ok:
                print(
                    f"external-services: export HTTP {response.status_code} for {pid}",
                    flush=True,
                )
                continue
            exported_dv_json = response.text
            if WEBHOOKDEBUG:
                print(exported_dv_json)

            safe_id = identifier.replace("/", "_")
            f_exported_dv_json = f"/tmp/{safe_id}.json"
            with open(f_exported_dv_json, "w") as f:
                f.write(exported_dv_json)

            # Connect any services here:
            # result = subprocess.run([...], shell=False, capture_output=True, text=True)
