# Databricks notebook source
# MAGIC %md
# MAGIC # Job monitoring and logging
# MAGIC - Log job run metadata to Azure Monitor or a Delta table for dashboards.

# COMMAND ----------

from datetime import datetime, timezone
import json

def log_run_metadata(job_name: str, run_id: str, status: str, duration_seconds: float = None, error_message: str = None):
    payload = {
        "job_name": job_name,
        "run_id": run_id,
        "status": status,
        "ts_utc": datetime.now(timezone.utc).isoformat(),
        "duration_seconds": duration_seconds,
        "error_message": error_message,
    }
    # Write to Delta table or send to Azure Monitor REST API
    print(json.dumps(payload))

# COMMAND ----------

# Example: at end of a job notebook
# log_run_metadata("RetailFlow_Main_Pipeline", "12345", "SUCCESS", duration_seconds=1200)
