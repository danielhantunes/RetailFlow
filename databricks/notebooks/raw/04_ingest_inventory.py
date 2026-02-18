# Databricks notebook source
# MAGIC %md
# MAGIC # RAW Ingestion: Inventory
# MAGIC - Ingests inventory snapshots (JSON or Parquet) from source; writes to RAW as-is.
# MAGIC - Partition by ingestion_date.

# COMMAND ----------

dbutils.widgets.text("source_path", "", "Source path (file or directory)")
dbutils.widgets.text("raw_base_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/inventory", "RAW base path")
dbutils.widgets.text("format", "json", "Source format: json or parquet")
source_path = dbutils.widgets.get("source_path")
raw_base = dbutils.widgets.get("raw_base_path")
src_fmt = dbutils.widgets.get("format")

# COMMAND ----------

from datetime import datetime, timezone

def ingestion_date_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

# COMMAND ----------

# Copy files to RAW without transformation (path-based copy)
ingestion_dt = ingestion_date_utc()
batch = batch_id()
dest_path = f"{raw_base}/ingestion_date={ingestion_dt}/inventory_{batch}.{src_fmt}"
dbutils.fs.cp(source_path, dest_path, recurse=False)
print(f"Copied to: {dest_path}")
