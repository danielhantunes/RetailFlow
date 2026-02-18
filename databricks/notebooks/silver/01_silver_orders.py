# Databricks notebook source
# MAGIC %md
# MAGIC # Silver: Orders
# MAGIC - Clean; deduplicate by order_id + updated_at; validate; business keys.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.window import Window

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")

bronze = spark.table(f"{catalog}.bronze.orders")

# Dedupe: keep latest by order_id per ingestion
w = Window.partitionBy("order_id").orderBy(F.col("updated_at").desc(), F.col("_ingestion_ts").desc())
silver = bronze.withColumn("_rn", F.row_number().over(w)).filter(F.col("_rn") == 1).drop("_rn")

# Clean: trim strings, valid status
silver = silver.withColumn("order_id", F.trim(F.col("order_id")))
silver = silver.withColumn("status", F.upper(F.trim(F.col("status"))))
silver = silver.filter(F.col("order_id").isNotNull())

# Optional: cast dates
silver = silver.withColumn("order_date", F.to_date(F.col("order_date"), "yyyy-MM-dd"))

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{catalog}.silver.orders")
