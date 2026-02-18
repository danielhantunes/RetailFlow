# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Products
# MAGIC - Read RAW CSV; add audit columns; write Delta with schema enforcement.

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_base = spark.conf.get("retailflow.raw_products_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/products")

raw_path = f"{raw_base}/ingestion_date=*"
df = spark.read.option("header", "true").option("inferSchema", "true").csv(raw_path)
df = df.withColumn("_ingestion_ts", F.current_timestamp()).withColumn("_source_file", F.input_file_name())
df = df.withColumn("ingestion_date", F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1))

df.write.format("delta").mode("append").partitionBy("ingestion_date").saveAsTable(f"{catalog}.bronze.products")
