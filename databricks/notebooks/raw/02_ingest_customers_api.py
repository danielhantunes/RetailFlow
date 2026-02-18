# Databricks notebook source
# MAGIC %md
# MAGIC # RAW Ingestion: Customers (REST API)
# MAGIC - Fetches from Customers API; writes to RAW as-is. Partition by ingestion_date.

# COMMAND ----------

dbutils.widgets.text("raw_base_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/customers", "RAW base path")
dbutils.widgets.text("customers_api_url", "", "Customers API base URL")
raw_base = dbutils.widgets.get("raw_base_path")
api_base = dbutils.widgets.get("customers_api_url") or spark.conf.get("retailflow.customers_api_url", "")

# COMMAND ----------

from datetime import datetime, timezone
import requests
import json

def get_api_key():
    return dbutils.secrets.get(scope="retailflow-keyvault", key="customers-api-key")

def ingestion_date_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

def fetch_customers(base_url: str, token: str, page: int = 1, per_page: int = 1000):
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = f"{base_url.rstrip('/')}?page={page}&per_page={per_page}"
    resp = requests.get(url, headers=headers, timeout=60)
    resp.raise_for_status()
    return resp.json()

def fetch_all(base_url: str, token: str, per_page: int = 1000, max_pages: int = 50):
    all_data = []
    page = 1
    while page <= max_pages:
        data = fetch_customers(base_url, token, page=page, per_page=per_page)
        items = data if isinstance(data, list) else data.get("items", data.get("customers", []))
        if not items:
            break
        all_data.extend(items)
        if len(items) < per_page:
            break
        page += 1
    return all_data

# COMMAND ----------

ingestion_dt = ingestion_date_utc()
batch = batch_id()
path = f"{raw_base}/ingestion_date={ingestion_dt}/batch_{batch}.json"

token = get_api_key()
payload = fetch_all(api_base, token)
raw_json = json.dumps(payload, default=str)
dbutils.fs.put(path, raw_json, overwrite=False)
print(f"Written: {path}, records: {len(payload)}")
