# Databricks notebook source
# MAGIC %md
# MAGIC # Gold: dim_customer (SCD Type 2)
# MAGIC - Dimension with effective_from / effective_to for history.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.window import Window

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
customers = spark.table(f"{catalog}.silver.customers")

# Build SCD2: effective_from = updated_at, effective_to = lead(updated_at) or '9999-12-31'
w = Window.partitionBy("customer_id").orderBy(F.col("updated_at"))
dim = customers.withColumn("effective_from", F.coalesce(F.to_timestamp("updated_at"), F.current_timestamp()))
dim = dim.withColumn("effective_to", F.lead(F.col("effective_from"), 1).over(w))
dim = dim.withColumn("effective_to", F.when(F.col("effective_to").isNull(), F.lit("9999-12-31").cast("timestamp")).otherwise(F.col("effective_to")))
dim = dim.withColumn("is_current", F.col("effective_to").cast("string").contains("9999"))

dim.select("customer_id", "email", "first_name", "last_name", "effective_from", "effective_to", "is_current") \
    .write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.dim_customer")

spark.sql(f"OPTIMIZE {catalog}.gold.dim_customer ZORDER BY (customer_id)")
