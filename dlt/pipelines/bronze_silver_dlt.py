# Databricks notebook source
# MAGIC %md
# MAGIC # Delta Live Tables: RAW → Bronze → Silver (Orders)
# MAGIC - DLT pipeline definition for incremental Bronze and Silver with expectations.

# COMMAND ----------

import dlt
from pyspark.sql import functions as F

# Config: set in pipeline settings
raw_orders_path = spark.conf.get("retailflow.raw_orders_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/orders")
catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")

# COMMAND ----------

@dlt.table(
    name="bronze_orders",
    comment="Bronze orders from RAW JSON",
    table_properties={"quality": "bronze"}
)
def bronze_orders():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation", f"abfss://processed@retailflowdevsa.dfs.core.windows.net/schemas/bronze_orders")
        .load(f"{raw_orders_path}/ingestion_date=*")
        .withColumn("_ingestion_ts", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
        .withColumn("ingestion_date", F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1))
    )

# COMMAND ----------

@dlt.table(
    name="silver_orders",
    comment="Cleaned and deduplicated orders",
    table_properties={"quality": "silver"}
)
@dlt.expect_or_fail("valid_order_id", "order_id IS NOT NULL")
@dlt.expect("valid_amount", "total_amount >= 0 OR total_amount IS NULL")
def silver_orders():
    return (
        dlt.read_stream("bronze_orders")
        .select(
            F.col("order_id"),
            F.col("customer_id"),
            F.to_date("order_date", "yyyy-MM-dd").alias("order_date"),
            F.upper(F.trim("status")).alias("status"),
            F.col("total_amount"),
            F.col("currency"),
            F.col("created_at"),
            F.col("updated_at"),
            F.col("_ingestion_ts")
        )
        .dropDuplicates(["order_id"])
    )
