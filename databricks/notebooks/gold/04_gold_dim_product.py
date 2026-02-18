# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: dim_product
# MAGIC - Product dimension from silver.products.

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
products = spark.table(f"{catalog}.silver.products")

dim = products.select(
    F.col("product_id"),
    F.col("name").alias("product_name"),
    F.col("category"),
    F.col("sku"),
    F.col("price"),
    F.col("updated_at")
).distinct()

dim.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.dim_product")
spark.sql(f"OPTIMIZE {catalog}.gold.dim_product ZORDER BY (product_id)")
