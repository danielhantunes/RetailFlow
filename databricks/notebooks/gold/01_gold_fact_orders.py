# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: fact_orders
# MAGIC - Reporting-ready fact from silver orders (and optional payments/line items).

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")

orders = spark.table(f"{catalog}.silver.orders")

fact = orders.select(
    F.col("order_id"),
    F.col("customer_id"),
    F.col("order_date"),
    F.col("status"),
    F.col("total_amount"),
    F.col("currency"),
    F.col("created_at"),
    F.col("updated_at")
).withColumn("order_year_month", F.date_format(F.col("order_date"), "yyyy-MM"))

fact.write.format("delta").mode("overwrite").partitionBy("order_year_month") \
    .option("overwriteSchema", "true").saveAsTable(f"{catalog}.gold.fact_orders")

# Optimize for analytics
spark.sql(f"OPTIMIZE {catalog}.gold.fact_orders ZORDER BY (order_id, customer_id, order_date)")
