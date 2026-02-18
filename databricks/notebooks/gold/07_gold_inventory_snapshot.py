# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: Inventory snapshot
# MAGIC - Point-in-time inventory by product (and store if applicable) for reporting.

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
inventory = spark.table(f"{catalog}.silver.inventory")

snapshot = inventory.select(
    F.col("product_id"),
    F.col("quantity").alias("on_hand_quantity"),
    F.col("snapshot_date"),
    F.col("store_id")
).filter(F.col("snapshot_date").isNotNull())

snapshot.write.format("delta").mode("overwrite").partitionBy("snapshot_date").saveAsTable(f"{catalog}.gold.inventory_snapshot")
spark.sql(f"OPTIMIZE {catalog}.gold.inventory_snapshot ZORDER BY (product_id, store_id)")
