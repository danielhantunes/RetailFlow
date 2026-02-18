# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: fact_sales
# MAGIC - Combines store sales and online orders into unified fact_sales (when store_sales silver exists).

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")

orders = spark.table(f"{catalog}.silver.orders")
orders = orders.withColumn("channel", F.lit("online")).withColumn("order_year_month", F.date_format(F.col("order_date"), "yyyy-MM"))
try:
    store_sales = spark.table(f"{catalog}.silver.store_sales").withColumn("channel", F.lit("store"))
    store_sales = store_sales.withColumn("order_year_month", F.date_format(F.col("sale_date"), "yyyy-MM"))
    fact_sales = orders.unionByName(store_sales, allowMissingColumns=True)
except Exception:
    fact_sales = orders

fact_sales.write.format("delta").mode("overwrite").partitionBy("order_year_month") \
    .saveAsTable(f"{catalog}.gold.fact_sales")

spark.sql(f"OPTIMIZE {catalog}.gold.fact_sales ZORDER BY (order_id, customer_id, order_date)")
