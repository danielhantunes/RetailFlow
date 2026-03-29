import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import uuid4

import azure.functions as func
import psycopg2
from azure.identity import DefaultAzureCredential
from azure.storage.filedatalake import DataLakeServiceClient

app = func.FunctionApp()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(ts: datetime) -> str:
    return ts.isoformat()


def _default_tables() -> List[Dict[str, str]]:
    return [
        {"table": "orders", "pk": "order_id", "watermark_column": "order_purchase_timestamp"},
        {"table": "order_items", "pk": "order_id", "watermark_column": "shipping_limit_date"},
        {"table": "order_payments", "pk": "order_id", "watermark_column": "payment_sequential"},
        {"table": "order_reviews", "pk": "review_id", "watermark_column": "review_creation_date"},
        {"table": "customers", "pk": "customer_id"},
        {"table": "products", "pk": "product_id"},
        {"table": "sellers", "pk": "seller_id"},
        {"table": "geolocation", "pk": "geolocation_zip_code_prefix"},
    ]


def _load_table_config() -> List[Dict[str, str]]:
    raw = os.environ.get("INGEST_TABLE_CONFIG_JSON", "").strip()
    if not raw:
        return _default_tables()
    try:
        parsed = json.loads(raw)
        if not isinstance(parsed, list):
            raise ValueError("INGEST_TABLE_CONFIG_JSON must be a JSON array")
        return parsed
    except Exception as exc:
        logging.warning("Invalid INGEST_TABLE_CONFIG_JSON; using defaults (%s)", exc)
        return _default_tables()


def _adls_client(storage_account: str, container: str):
    credential = DefaultAzureCredential()
    service = DataLakeServiceClient(
        account_url=f"https://{storage_account}.dfs.core.windows.net",
        credential=credential,
    )
    return service.get_file_system_client(container)


def _read_json(fs, path: str) -> Optional[Dict[str, Any]]:
    try:
        data = fs.get_file_client(path).download_file().readall()
        return json.loads(data.decode("utf-8"))
    except Exception:
        return None


def _write_json(fs, path: str, payload: Dict[str, Any]) -> None:
    fs.get_file_client(path).upload_data(
        json.dumps(payload, ensure_ascii=True, indent=2).encode("utf-8"),
        overwrite=True,
    )


def _write_checkpoint(fs, path: str, payload: Dict[str, Any]) -> None:
    tmp = f"{path}.tmp-{uuid4()}"
    _write_json(fs, tmp, payload)
    _write_json(fs, path, payload)
    try:
        fs.delete_file(tmp)
    except Exception:
        pass


def _escape_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _to_jsonable(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def _as_cursor_value(value: Any) -> str:
    if value is None:
        return ""
    return str(_to_jsonable(value))


def _build_chunk_sql(table: str, mode: str, wm_col: Optional[str], pk_col: Optional[str]) -> str:
    table_i = _escape_ident(table)
    where_clauses: List[str] = []
    order_clauses: List[str] = []

    if mode == "incremental":
        if not wm_col:
            raise ValueError(f"Incremental mode requires watermark_column for table {table}")
        wm_i = _escape_ident(wm_col)
        if pk_col:
            pk_i = _escape_ident(pk_col)
            where_clauses.append(
                f"(({wm_i} > %(last_wm)s) OR ({wm_i} = %(last_wm)s AND {pk_i} > %(last_pk)s))"
            )
            order_clauses.extend([wm_i, pk_i])
        else:
            where_clauses.append(f"{wm_i} > %(last_wm)s")
            order_clauses.append(wm_i)
        where_clauses.append(f"{wm_i} <= %(cutoff)s")
    else:
        if pk_col:
            pk_i = _escape_ident(pk_col)
            where_clauses.append(f"{pk_i} > %(last_pk)s")
            order_clauses.append(pk_i)
        elif wm_col:
            wm_i = _escape_ident(wm_col)
            where_clauses.append(f"{wm_i} > %(last_wm)s")
            order_clauses.append(wm_i)

    where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
    order_sql = f"ORDER BY {', '.join(order_clauses)}" if order_clauses else ""
    return f"SELECT * FROM {table_i} {where_sql} {order_sql} LIMIT %(chunk_size)s"


def _acquire_lock(conn) -> bool:
    with conn.cursor() as cur:
        cur.execute("SELECT pg_try_advisory_lock(%s);", (780011,))
        return bool(cur.fetchone()[0])


def _release_lock(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("SELECT pg_advisory_unlock(%s);", (780011,))


def _execute_postgres_to_raw() -> None:
    run_ts = _utc_now()
    run_ts_iso = _iso(run_ts)
    run_id = run_ts.strftime("%Y%m%dT%H%M%SZ")

    postgres_host = os.environ.get("POSTGRES_HOST")
    postgres_user = os.environ.get("POSTGRES_USER")
    postgres_password = os.environ.get("POSTGRES_PASSWORD")
    postgres_db = os.environ.get("POSTGRES_DB", "retailflow")
    raw_storage = os.environ.get("RAW_STORAGE_ACCOUNT")
    raw_container = os.environ.get("RAW_CONTAINER", "raw")
    mode = os.environ.get("INGESTION_MODE", "incremental").strip().lower()

    if mode not in ("initial", "incremental"):
        mode = "incremental"
    if not all([postgres_host, postgres_user, postgres_password, raw_storage]):
        logging.error("Missing required app settings; aborting run")
        return

    fs = _adls_client(raw_storage, raw_container)
    table_config = _load_table_config()
    chunk_size = int(os.environ.get("INGEST_CHUNK_SIZE", "50000"))
    ingestion_date = run_ts.strftime("%Y-%m-%d")
    ingestion_hour = run_ts.strftime("%H")
    control_prefix = os.environ.get("WATERMARK_CONTROL_PREFIX", "_control/postgres_watermarks").strip("/")
    raw_prefix = os.environ.get("RAW_PREFIX", "postgres_ingest").strip("/")
    default_start = os.environ.get("INITIAL_WATERMARK", "1900-01-01T00:00:00Z")

    manifest_path = (
        f"{raw_prefix}/_runs/ingestion_date={ingestion_date}/hour={ingestion_hour}/run_{run_id}.json"
    )
    manifest: Dict[str, Any] = {
        "run_id": run_id,
        "mode": mode,
        "status": "running",
        "started_utc": run_ts_iso,
        "chunk_size": chunk_size,
        "tables": [],
    }
    _write_json(fs, manifest_path, manifest)

    conn = psycopg2.connect(
        host=postgres_host,
        user=postgres_user,
        password=postgres_password,
        dbname=postgres_db,
        sslmode="require",
    )
    conn.autocommit = True
    if not _acquire_lock(conn):
        manifest["status"] = "skipped_lock_active"
        manifest["ended_utc"] = _iso(_utc_now())
        _write_json(fs, manifest_path, manifest)
        conn.close()
        return

    processed_tables = 0
    try:
        for cfg in table_config:
            table = cfg.get("table")
            if not table:
                continue
            wm_col = cfg.get("watermark_column")
            pk_col = cfg.get("pk")
            checkpoint_path = f"{control_prefix}/{table}.json"
            checkpoint = _read_json(fs, checkpoint_path) or {}
            last_wm = checkpoint.get("last_watermark", default_start)
            last_pk = checkpoint.get("last_pk", "")
            last_chunk_index = int(checkpoint.get("last_chunk_index", 0))
            cutoff = run_ts_iso

            try:
                sql = _build_chunk_sql(table, mode, wm_col, pk_col)
            except ValueError as exc:
                logging.info("%s", exc)
                continue

            table_rows = 0
            chunks_written = 0
            table_start = _iso(_utc_now())
            latest_path = checkpoint.get("last_raw_file_path", "")

            while True:
                params = {
                    "last_wm": last_wm,
                    "last_pk": last_pk,
                    "cutoff": cutoff,
                    "chunk_size": chunk_size,
                }
                with conn.cursor() as cur:
                    cur.execute(sql, params)
                    rows = cur.fetchall()
                    if not rows:
                        break
                    columns = [d[0] for d in cur.description]

                chunk_index = last_chunk_index + 1
                chunk_lines: List[str] = []
                chunk_last_wm = last_wm
                chunk_last_pk = last_pk
                chunk_row_count = 0

                for row in rows:
                    chunk_row_count += 1
                    obj = {columns[i]: _to_jsonable(row[i]) for i in range(len(columns))}
                    obj["_source_table"] = table
                    obj["_ingestion_ts"] = run_ts_iso
                    obj["_batch_id"] = run_id
                    obj["_ingestion_mode"] = mode
                    obj["_chunk_index"] = chunk_index
                    chunk_lines.append(json.dumps(obj, ensure_ascii=True))

                    if wm_col:
                        wm_val = obj.get(wm_col)
                        if wm_val is not None:
                            chunk_last_wm = _as_cursor_value(wm_val)
                    if pk_col:
                        pk_val = obj.get(pk_col)
                        if pk_val is not None:
                            chunk_last_pk = _as_cursor_value(pk_val)

                raw_path = (
                    f"{raw_prefix}/{table}/ingestion_date={ingestion_date}/hour={ingestion_hour}/"
                    f"batch_id={run_id}/chunk_{chunk_index:05d}.jsonl"
                )
                fs.get_file_client(raw_path).upload_data(
                    ("\n".join(chunk_lines) + "\n").encode("utf-8"),
                    overwrite=True,
                )

                last_chunk_index = chunk_index
                last_wm = chunk_last_wm
                last_pk = chunk_last_pk
                latest_path = raw_path
                table_rows += chunk_row_count
                chunks_written += 1

                in_progress = {
                    "table": table,
                    "mode": mode,
                    "watermark_column": wm_col,
                    "pk_column": pk_col,
                    "last_watermark": last_wm if wm_col else checkpoint.get("last_watermark", default_start),
                    "last_pk": last_pk if pk_col else checkpoint.get("last_pk", ""),
                    "last_chunk_index": last_chunk_index,
                    "last_success_utc": run_ts_iso,
                    "row_count_last_chunk": chunk_row_count,
                    "row_count_last_run_table_total": table_rows,
                    "batch_id": run_id,
                    "last_raw_file_path": raw_path,
                    "status": "in_progress",
                }
                _write_checkpoint(fs, checkpoint_path, in_progress)

            final_cp = {
                "table": table,
                "mode": mode,
                "watermark_column": wm_col,
                "pk_column": pk_col,
                "last_watermark": last_wm if wm_col else checkpoint.get("last_watermark", default_start),
                "last_pk": last_pk if pk_col else checkpoint.get("last_pk", ""),
                "last_chunk_index": last_chunk_index,
                "last_success_utc": run_ts_iso,
                "row_count_last_run_table_total": table_rows,
                "batch_id": run_id,
                "last_raw_file_path": latest_path,
                "status": "completed",
            }
            _write_checkpoint(fs, checkpoint_path, final_cp)
            manifest["tables"].append(
                {
                    "table": table,
                    "rows": table_rows,
                    "chunks": chunks_written,
                    "started_utc": table_start,
                    "ended_utc": _iso(_utc_now()),
                    "checkpoint_path": checkpoint_path,
                    "last_raw_file_path": latest_path,
                }
            )
            processed_tables += 1

        manifest["status"] = "completed"
        manifest["processed_tables"] = processed_tables
    except Exception as exc:
        manifest["status"] = "failed"
        manifest["error"] = str(exc)
        raise
    finally:
        manifest["ended_utc"] = _iso(_utc_now())
        _write_json(fs, manifest_path, manifest)
        try:
            _release_lock(conn)
        except Exception:
            pass
        conn.close()

    logging.info("Postgres->RAW run finished: tables=%s", processed_tables)


@app.timer_trigger(
    arg_name="timer",
    schedule="%POSTGRES_TIMER_SCHEDULE%",
    run_on_startup=False,
)
def postgres_to_raw_timer(timer: func.TimerRequest) -> None:
    _execute_postgres_to_raw()


# On-demand runs from CI (admin/timer invoke URLs are unreliable for Python v2). POST with function or host key.
@app.route(
    route="postgres-to-raw/run",
    methods=["POST"],
    auth_level=func.AuthLevel.FUNCTION,
)
def postgres_to_raw_http(_req: func.HttpRequest) -> func.HttpResponse:
    _execute_postgres_to_raw()
    return func.HttpResponse(
        '{"status":"completed"}',
        status_code=200,
        mimetype="application/json",
    )
