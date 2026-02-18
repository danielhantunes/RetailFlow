# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: dim_store
# MAGIC - Store dimension from silver.store or silver.store_sales (store_id, name, region).

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
# If silver.stores exists; else build from store_sales
try:
    stores = spark.table(f"{catalog}.silver.stores")
except Exception:
    store_sales = spark.table(f"{catalog}.silver.store_sales")
    stores = store_sales.select("store_id", "store_name", "region").distinct()

dim = stores.select(
    F.col("store_id"),
    F.col("store_name"),
    F.col("region")
)
dim.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.dim_store")
spark.sql(f"OPTIMIZE {catalog}.gold.dim_store ZORDER BY (store_id)")
