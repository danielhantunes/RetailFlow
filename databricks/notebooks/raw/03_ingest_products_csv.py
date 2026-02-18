# Databricks notebook source
# MAGIC %md
# MAGIC # RAW Ingestion: Products (CSV)
# MAGIC - Reads CSV from source path (e.g. export from catalog system) and writes to RAW unchanged.
# MAGIC - Partition by ingestion_date. Immutable.

# COMMAND ----------

dbutils.widgets.text("source_csv_path", "", "Source CSV path (e.g. abfss://... or /mnt/...)")
dbutils.widgets.text("raw_base_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/products", "RAW base path")
source_path = dbutils.widgets.get("source_csv_path")
raw_base = dbutils.widgets.get("raw_base_path")

# COMMAND ----------

from datetime import datetime, timezone

def ingestion_date_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

# COMMAND ----------

# Read as binary/text to preserve exact content (no schema inference)
raw_content = dbutils.fs.head(source_path, maxBytes=50 * 1024 * 1024)  # 50 MB max for single file
# For large files, stream copy instead of head. Here we assume moderate-sized CSV.
full_content = spark.sparkContext.wholeTextFiles(source_path).collect()
if full_content:
    _, content = full_content[0]
else:
    content = raw_content

ingestion_dt = ingestion_date_utc()
batch = batch_id()
path = f"{raw_base}/ingestion_date={ingestion_dt}/products_{batch}.csv"
dbutils.fs.put(path, content, overwrite=False)
print(f"Written: {path}")
