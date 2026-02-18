# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Orders
# MAGIC - Read RAW JSON from ADLS; flatten; add audit columns; write Delta with schema enforcement.

# COMMAND ----------

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType, IntegerType

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_base = spark.conf.get("retailflow.raw_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/orders")
bronze_path = f"catalog.{catalog}.bronze.orders"

# COMMAND ----------

# Incremental: process only new ingestion_date partitions or use checkpoint
raw_path = f"{raw_base}/ingestion_date=*"
df_raw = spark.read.schema("value STRING").format("text").load(raw_path)

# Parse JSON and add audit columns from path
df = df_raw.withColumn("_parsed", F.from_json(F.col("value"), "order_id STRING, customer_id STRING, order_date STRING, status STRING, total_amount DOUBLE, currency STRING, created_at STRING, updated_at STRING"))
df = df.withColumn("_ingestion_ts", F.current_timestamp())
df = df.withColumn("_source_file", F.input_file_name())
df = df.withColumn("ingestion_date", F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1))

# Flatten and select
bronze = df.select(
    F.col("_parsed.order_id").alias("order_id"),
    F.col("_parsed.customer_id").alias("customer_id"),
    F.col("_parsed.order_date").alias("order_date"),
    F.col("_parsed.status").alias("status"),
    F.col("_parsed.total_amount").alias("total_amount"),
    F.col("_parsed.currency").alias("currency"),
    F.col("_parsed.created_at").alias("created_at"),
    F.col("_parsed.updated_at").alias("updated_at"),
    F.col("ingestion_date"),
    F.col("_ingestion_ts").alias("_ingestion_ts"),
    F.col("_source_file").alias("_source_file")
).drop("_parsed", "value")

# COMMAND ----------

# Write Delta with mergeSchema for evolution; partition by ingestion_date
bronze.write.format("delta").mode("append").partitionBy("ingestion_date").saveAsTable(bronze_path)
