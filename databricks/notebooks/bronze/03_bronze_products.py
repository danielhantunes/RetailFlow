# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Products
# MAGIC - Read RAW from ADLS: Postgres JSONL (default) or CSV under data/raw/products if configured.
# MAGIC - Add audit columns; write Delta with mergeSchema.

# COMMAND ----------

from pyspark.sql import functions as F

storage_account = spark.conf.get("retailflow.storage_account", "retailflowdevdls")
raw_container = spark.conf.get("retailflow.raw_container", "raw")
catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
# postgres_ingest/products for Olist; set retailflow.raw_products_format=csv and retailflow.raw_products_rel_path=data/raw/products for legacy CSV.
raw_products_rel = spark.conf.get("retailflow.raw_products_rel_path", "postgres_ingest/products")
raw_format = spark.conf.get("retailflow.raw_products_format", "json").strip().lower()

raw_base = f"abfss://{raw_container}@{storage_account}.dfs.core.windows.net/{raw_products_rel.strip('/')}"

# COMMAND ----------

if raw_format == "csv":
    df = (
        spark.read.option("header", "true")
        .option("inferSchema", "true")
        .option("recursiveFileLookup", "true")
        .csv(raw_base)
    )
else:
    df = spark.read.option("recursiveFileLookup", "true").json(raw_base)

df = (
    df.withColumn("_ingestion_ts", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
    .withColumn(
        "ingestion_date",
        F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1),
    )
)

# COMMAND ----------

df.write.format("delta").mode("append").option("mergeSchema", "true").partitionBy("ingestion_date").saveAsTable(
    f"{catalog}.bronze.products"
)
