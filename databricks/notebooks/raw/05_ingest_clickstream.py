# Databricks notebook source
# MAGIC %md
# MAGIC # RAW Ingestion: Clickstream (JSON/NDJSON)
# MAGIC - Reads clickstream events from source (e.g. event hub capture or blob) and writes to RAW.
# MAGIC - One file per batch; partition by ingestion_date. Immutable.

# COMMAND ----------

dbutils.widgets.text("source_path", "", "Source path (directory of NDJSON or single file)")
dbutils.widgets.text("raw_base_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/clickstream", "RAW base path")
source_path = dbutils.widgets.get("source_path")
raw_base = dbutils.widgets.get("raw_base_path")

# COMMAND ----------

from datetime import datetime, timezone

def ingestion_date_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

# COMMAND ----------

# Read as text, write as-is (no parsing in RAW)
df = spark.read.text(source_path)
ingestion_dt = ingestion_date_utc()
batch = batch_id()
dest_path = f"{raw_base}/ingestion_date={ingestion_dt}/clickstream_{batch}.ndjson"
df.write.mode("append").text(dest_path.replace(".ndjson", ""))  # Spark text writes to dir
# Alternative: coalesce to single file then move
# df.coalesce(1).write.mode("overwrite").text(...)
print(f"Written to: {dest_path}")
