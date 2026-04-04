# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Orders
# MAGIC - Read RAW from ADLS (JSON lines from Postgres ingest, or JSON batches from API ingest).
# MAGIC - Add audit columns; normalize Olist column names when present; write Delta to Unity Catalog.

# COMMAND ----------

from pyspark.sql import functions as F

# Defaults align with terraform/adls (retailflowdevdls) and Postgres → RAW layout (postgres_ingest/...).
# Override: spark.conf "retailflow.storage_account", "retailflow.raw_orders_rel_path" (e.g. data/raw/orders for API-only).
storage_account = spark.conf.get("retailflow.storage_account", "retailflowdevdls")
raw_container = spark.conf.get("retailflow.raw_container", "raw")
catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_orders_rel = spark.conf.get("retailflow.raw_orders_rel_path", "postgres_ingest/orders")

raw_base = f"abfss://{raw_container}@{storage_account}.dfs.core.windows.net/{raw_orders_rel.strip('/')}"

# COMMAND ----------

# Recursive load picks up ingestion_date=/hour=/batch_id=/chunk_*.jsonl (Postgres) or ingestion_date=/batch_*.json (API).
df = (
    spark.read.option("recursiveFileLookup", "true")
    .json(raw_base)
    .withColumn("_bronze_ingestion_ts", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
    .withColumn(
        "ingestion_date",
        F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1),
    )
)

# Postgres rows include _ingestion_ts (source); keep for ordering Silver dedupe.
if "_ingestion_ts" in df.columns:
    df = df.withColumn("_source_ingestion_ts", F.col("_ingestion_ts"))

# Olist / Postgres shape → canonical columns expected by Silver/Gold notebooks
if "order_status" in df.columns and "status" not in df.columns:
    df = df.withColumn("status", F.col("order_status"))
if "order_purchase_timestamp" in df.columns:
    if "order_date" not in df.columns:
        df = df.withColumn("order_date", F.to_date(F.col("order_purchase_timestamp")))
    if "created_at" not in df.columns:
        df = df.withColumn("created_at", F.col("order_purchase_timestamp"))
if "updated_at" not in df.columns:
    _parts = []
    for _c in (
        "order_delivered_customer_date",
        "order_approved_at",
        "order_purchase_timestamp",
    ):
        if _c in df.columns:
            _parts.append(F.col(_c))
    if "_source_ingestion_ts" in df.columns:
        _parts.append(F.col("_source_ingestion_ts"))
    if _parts:
        df = df.withColumn("updated_at", F.coalesce(*_parts))
    else:
        df = df.withColumn("updated_at", F.lit(None).cast("string"))
if "total_amount" not in df.columns:
    df = df.withColumn("total_amount", F.lit(None).cast("double"))
if "currency" not in df.columns:
    df = df.withColumn("currency", F.lit("BRL"))

# Audit: single _ingestion_ts for Bronze run (keep distinct from source _ingestion_ts)
bronze = df.withColumn("_ingestion_ts", F.col("_bronze_ingestion_ts")).drop("_bronze_ingestion_ts")

# COMMAND ----------

bronze.write.format("delta").mode("append").option("mergeSchema", "true").partitionBy("ingestion_date").saveAsTable(
    f"{catalog}.bronze.orders"
)
