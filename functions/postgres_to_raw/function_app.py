# Azure Function: Postgres → ADLS RAW ingestion (timer-triggered).
# Runs in the base VNet; reads from Azure PostgreSQL, writes to ADLS Gen2 RAW container.
# Configure: POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, RAW_STORAGE_ACCOUNT, RAW_CONTAINER (app settings).

import os
import json
import logging
from datetime import datetime, timezone

import azure.functions as func

app = func.FunctionApp()


@app.timer_trigger(schedule="0 */15 * * * *", arg_name="timer", run_on_startup=False)
def postgres_to_raw_timer(timer: func.TimerRequest) -> None:
    """Run every 15 minutes: read from Postgres, write to ADLS RAW (ingestion_date partition)."""
    logging.info("Postgres to RAW timer triggered at %s", datetime.now(timezone.utc).isoformat())

    postgres_host = os.environ.get("POSTGRES_HOST")
    postgres_user = os.environ.get("POSTGRES_USER")
    postgres_password = os.environ.get("POSTGRES_PASSWORD")
    postgres_db = os.environ.get("POSTGRES_DB", "retailflow")
    raw_storage = os.environ.get("RAW_STORAGE_ACCOUNT")
    raw_container = os.environ.get("RAW_CONTAINER", "raw")

    if not all([postgres_host, postgres_user, postgres_password]):
        logging.warning("Postgres or RAW app settings missing; skipping ingest (placeholder run)")
        return

    # Placeholder: connect and write one small payload to RAW for structure validation.
    # Replace with real logic: query Postgres (incremental or full), write JSON/Parquet to
    # abfss://<container>@<storage>.dfs.core.windows.net/raw/<entity>/ingestion_date=YYYY-MM-DD/...
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=postgres_host,
            user=postgres_user,
            password=postgres_password,
            dbname=postgres_db,
            sslmode="require",
        )
        with conn.cursor() as cur:
            cur.execute("SELECT 1 AS heartbeat")
            row = cur.fetchone()
        conn.close()
        logging.info("Postgres connectivity OK (heartbeat=%s)", row)
    except Exception as e:
        logging.warning("Postgres connect failed (expected if not yet configured): %s", e)

    # Placeholder: write a small metadata file to RAW to validate managed identity + path.
    if raw_storage and raw_container:
        try:
            from azure.identity import DefaultAzureCredential
            from azure.storage.filedatalake import DataLakeServiceClient
            credential = DefaultAzureCredential()
            url = f"https://{raw_storage}.dfs.core.windows.net"
            service = DataLakeServiceClient(account_url=url, credential=credential)
            file_system = service.get_file_system_client(raw_container)
            today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            path = f"postgres_ingest/ingestion_date={today}/heartbeat.json"
            file_client = file_system.get_file_client(path)
            payload = {"source": "postgres_to_raw_timer", "ts": datetime.now(timezone.utc).isoformat()}
            file_client.upload_data(json.dumps(payload).encode(), overwrite=True)
            logging.info("Wrote placeholder to RAW: %s", path)
        except Exception as e:
            logging.warning("ADLS write failed (expected if not yet configured): %s", e)

    logging.info("Postgres to RAW timer finished")
