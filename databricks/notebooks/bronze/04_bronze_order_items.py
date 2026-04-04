# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Order items
# MAGIC - Read RAW JSONL from ADLS (`postgres_ingest/order_items` by default).
# MAGIC - Add audit columns; write Delta with mergeSchema.

# COMMAND ----------

from pyspark.sql import functions as F

storage_account = spark.conf.get("retailflow.storage_account", "retailflowdevdls")
raw_container = spark.conf.get("retailflow.raw_container", "raw")
catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_rel = spark.conf.get("retailflow.raw_order_items_rel_path", "postgres_ingest/order_items")

raw_base = f"abfss://{raw_container}@{storage_account}.dfs.core.windows.net/{raw_rel.strip('/')}"

# COMMAND ----------

df = (
    spark.read.option("recursiveFileLookup", "true")
    .json(raw_base)
    .withColumn("_ingestion_ts", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
    .withColumn(
        "ingestion_date",
        F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1),
    )
)

# COMMAND ----------

df.write.format("delta").mode("append").option("mergeSchema", "true").partitionBy("ingestion_date").saveAsTable(
    f"{catalog}.bronze.order_items"
)
