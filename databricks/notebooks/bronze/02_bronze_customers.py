# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Customers
# MAGIC - Read RAW JSON from ADLS (Postgres JSONL under postgres_ingest/customers or API-style paths).
# MAGIC - Add audit columns; map Olist fields to canonical names for Silver; write Delta.

# COMMAND ----------

from pyspark.sql import functions as F

storage_account = spark.conf.get("retailflow.storage_account", "retailflowdevdls")
raw_container = spark.conf.get("retailflow.raw_container", "raw")
catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_customers_rel = spark.conf.get("retailflow.raw_customers_rel_path", "postgres_ingest/customers")

raw_base = f"abfss://{raw_container}@{storage_account}.dfs.core.windows.net/{raw_customers_rel.strip('/')}"

# COMMAND ----------

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

if "_ingestion_ts" in df.columns:
    df = df.withColumn("_source_ingestion_ts", F.col("_ingestion_ts"))

# API-shaped rows already have email, first_name, etc.
# Olist: customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state — no PII email.
if "email" not in df.columns:
    df = df.withColumn("email", F.lit(None).cast("string"))
if "first_name" not in df.columns:
    df = df.withColumn("first_name", F.lit(None).cast("string"))
if "last_name" not in df.columns:
    df = df.withColumn("last_name", F.lit(None).cast("string"))
if "created_at" not in df.columns:
    df = df.withColumn("created_at", F.lit(None).cast("string"))
if "updated_at" not in df.columns:
    if "_source_ingestion_ts" in df.columns:
        df = df.withColumn("updated_at", F.col("_source_ingestion_ts"))
    else:
        df = df.withColumn("updated_at", F.lit(None).cast("string"))

bronze = df.withColumn("_ingestion_ts", F.col("_bronze_ingestion_ts")).drop("_bronze_ingestion_ts")

# COMMAND ----------

bronze.write.format("delta").mode("append").option("mergeSchema", "true").partitionBy("ingestion_date").saveAsTable(
    f"{catalog}.bronze.customers"
)
