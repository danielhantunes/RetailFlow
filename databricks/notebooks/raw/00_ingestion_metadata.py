# Databricks notebook source
# MAGIC %md
# MAGIC # Ingestion Metadata Helper
# MAGIC - Central place for ingestion_date, batch_id, and RAW path builders.
# MAGIC - Used by all RAW ingestion notebooks to ensure consistency and immutability.

# COMMAND ----------

from datetime import datetime, timezone
from typing import Optional

def ingestion_date_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def batch_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

def raw_path(base: str, entity: str, ingestion_dt: Optional[str] = None, suffix: str = "") -> str:
    dt = ingestion_dt or ingestion_date_utc()
    return f"{base.rstrip('/')}/data/raw/{entity}/ingestion_date={dt}{suffix}"
