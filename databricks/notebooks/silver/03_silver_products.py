# Databricks notebook source
# MAGIC %md
# MAGIC # Silver: Products
# MAGIC - Clean; deduplicate by product_id.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.window import Window

catalog = spark.conf.get("retailflow.catalog", "retailflow_dev")
bronze = spark.table(f"{catalog}.bronze.products")

w = Window.partitionBy("product_id").orderBy(F.col("_ingestion_ts").desc())
silver = bronze.withColumn("_rn", F.row_number().over(w)).filter(F.col("_rn") == 1).drop("_rn")
silver = silver.filter(F.col("product_id").isNotNull())

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{catalog}.silver.products")
