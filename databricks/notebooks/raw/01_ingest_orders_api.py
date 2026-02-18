# Databricks notebook source
# MAGIC %md
# MAGIC # RAW Ingestion: Orders (REST API)
# MAGIC - Fetches from Orders API, writes to ADLS RAW exactly as received.
# MAGIC - No transformations. Partition by ingestion_date. Append-only.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Config

# COMMAND ----------

dbutils.widgets.text("raw_base_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/orders", "RAW base path")
dbutils.widgets.text("orders_api_url", "", "Orders API base URL")
dbutils.widgets.dropdown("use_secret_scope", "true", ["true", "false"], "Use Key Vault for API key")
raw_base = dbutils.widgets.get("raw_base_path")
api_base = dbutils.widgets.get("orders_api_url") or spark.conf.get("retailflow.orders_api_url", "")

# COMMAND ----------

from datetime import datetime, timezone
import requests
import json

def get_api_key():
    if dbutils.widgets.get("use_secret_scope") == "true":
        return dbutils.secrets.get(scope="retailflow-keyvault", key="orders-api-key")
    return spark.conf.get("retailflow.orders_api_key", "")

def ingestion_date_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Fetch from API (paginated)

# COMMAND ----------

def fetch_orders_page(base_url: str, token: str, page: int = 1, per_page: int = 1000):
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = f"{base_url.rstrip('/')}?page={page}&per_page={per_page}"
    resp = requests.get(url, headers=headers, timeout=60)
    resp.raise_for_status()
    return resp.json()

def fetch_all_orders(base_url: str, token: str, max_pages: int = 100):
    all_data = []
    page = 1
    while page <= max_pages:
        data = fetch_orders_page(base_url, token, page=page)
        items = data if isinstance(data, list) else data.get("items", data.get("orders", []))
        if not items:
            break
        all_data.extend(items)
        if len(items) < 1000:
            break
        page += 1
    return all_data

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to RAW (immutable, one file per run)

# COMMAND ----------

ingestion_dt = ingestion_date_utc()
batch = batch_id()
path = f"{raw_base}/ingestion_date={ingestion_dt}/batch_{batch}.json"

token = get_api_key()
payload = fetch_all_orders(api_base, token)

# Write exact JSON; no schema change, no transform
raw_json = json.dumps(payload, default=str)
dbutils.fs.put(path, raw_json, overwrite=False)

print(f"Written: {path}, records: {len(payload)}")

# COMMAND ----------

# Optional: write manifest row for replay tracking (e.g. to a small Delta table or external store)
# dbtils.notebook.exit({"path": path, "ingestion_date": ingestion_dt, "batch_id": batch, "record_count": len(payload)})
