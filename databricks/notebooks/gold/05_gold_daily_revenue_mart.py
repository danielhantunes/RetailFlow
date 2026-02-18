# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: Daily Revenue Mart
# MAGIC - Aggregation by date for BI/reporting.

# COMMAND ----------

from pyspark.sql import functions as F

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
fact_orders = spark.table(f"{catalog}.gold.fact_orders")

daily = fact_orders.filter(F.col("status").isin("COMPLETED", "SHIPPED", "DELIVERED")) \
    .groupBy("order_date").agg(
        F.sum("total_amount").alias("revenue"),
        F.count("*").alias("order_count")
    ).withColumn("order_date", F.to_date("order_date"))

daily.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.daily_revenue_mart")
