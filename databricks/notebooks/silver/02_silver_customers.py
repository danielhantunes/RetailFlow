# Databricks notebook source
# MAGIC %md
# MAGIC # Silver: Customers
# MAGIC - Clean; deduplicate by customer_id; validate.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.window import Window

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
bronze = spark.table(f"{catalog}.bronze.customers")

w = Window.partitionBy("customer_id").orderBy(F.col("updated_at").desc(), F.col("_ingestion_ts").desc())
silver = bronze.withColumn("_rn", F.row_number().over(w)).filter(F.col("_rn") == 1).drop("_rn")
silver = silver.withColumn("email", F.trim(F.col("email"))).filter(F.col("customer_id").isNotNull())

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{catalog}.silver.customers")
