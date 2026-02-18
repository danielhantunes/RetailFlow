# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Customers
# MAGIC - Read RAW JSON; flatten; add audit columns; write Delta.

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
raw_base = spark.conf.get("retailflow.raw_customers_path", "abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw/customers")

raw_path = f"{raw_base}/ingestion_date=*"
df_raw = spark.read.schema("value STRING").format("text").load(raw_path)

df = df_raw.withColumn("_parsed", F.from_json(F.col("value"), "customer_id STRING, email STRING, first_name STRING, last_name STRING, created_at STRING, updated_at STRING"))
df = df.withColumn("_ingestion_ts", F.current_timestamp()).withColumn("_source_file", F.input_file_name())
df = df.withColumn("ingestion_date", F.regexp_extract(F.col("_source_file"), r"ingestion_date=(\d{4}-\d{2}-\d{2})", 1))

bronze = df.select(
    F.col("_parsed.customer_id").alias("customer_id"),
    F.col("_parsed.email").alias("email"),
    F.col("_parsed.first_name").alias("first_name"),
    F.col("_parsed.last_name").alias("last_name"),
    F.col("_parsed.created_at").alias("created_at"),
    F.col("_parsed.updated_at").alias("updated_at"),
    F.col("ingestion_date"),
    F.col("_ingestion_ts").alias("_ingestion_ts"),
    F.col("_source_file").alias("_source_file")
).drop("_parsed", "value")

bronze.write.format("delta").mode("append").partitionBy("ingestion_date").saveAsTable(f"{catalog}.bronze.customers")
