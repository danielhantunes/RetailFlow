# RetailFlow Data Platform — Architecture

## Overview

RetailFlow is an enterprise data platform for a retail company, built on **Azure Databricks** with a **medallion architecture** (RAW → BRONZE → SILVER → GOLD). It ingests online orders, store sales, product catalog, inventory, customers, payments, and clickstream events to support analytics, BI, and reporting.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SOURCE SYSTEMS                                          │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────┬────────────┤
│ REST APIs   │ SQL DB      │ JSON Logs   │ CSV         │ Inventory   │ Payments   │
│ (orders,    │ (extracts)  │ (clickstream)│ (products)  │ System      │ Gateway    │
│  customers) │             │             │             │             │            │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┘
       │             │             │             │             │             │
       ▼             ▼             ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    INGESTION (Notebooks / ADF / Airflow)                          │
└─────────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│  AZURE DATA LAKE STORAGE GEN2 (RAW) — Immutable, partition by ingestion_date     │
│  /data/raw/orders | customers | products | inventory | clickstream | payments   │
└─────────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│  UNITY CATALOG + DELTA LAKE                                                       │
│  BRONZE (Delta) → SILVER (Delta) → GOLD (Delta)                                  │
│  Schema enforcement, audit cols, dedup, SCD2, fact/dim tables                     │
└─────────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│  CONSUMERS: Power BI, Tableau, Databricks SQL, Reporting, ML                      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|--------|
| **Azure Databricks** | Compute for Spark (PySpark/SQL), Delta Live Tables, scheduled jobs |
| **Delta Lake** | Storage format for Bronze/Silver/Gold; ACID, time travel, Z-Order |
| **Unity Catalog** | Central governance: schemas, tables, roles, row/column access |
| **ADLS Gen2** | RAW layer and external Delta locations; hierarchical namespace |
| **Azure Key Vault** | Secrets; linked via Databricks secret scopes |
| **Azure Monitor** | Logs, metrics, alerts for jobs and pipelines |
| **Terraform** | Provision workspace, storage, Key Vault, service principals |
| **GitHub Actions** | CI/CD: deploy notebooks, jobs, promote dev → stg → prod |
| **Airflow (optional)** | Orchestrate RAW → Bronze → Silver → Gold DAGs |
| **dbt (optional)** | Transformations and marts in Gold |

## Medallion Layers

### RAW (ADLS Gen2)

- **Purpose:** Immutable landing; exact copy of source data.
- **Formats:** JSON, CSV, Parquet as received.
- **Partitioning:** `ingestion_date=YYYY-MM-DD` (and optionally `source`, `batch_id`).
- **Design:** No transformations; append-only; supports replay and schema evolution.
- **Paths:**  
  `/{container}/data/raw/orders/`, `customers/`, `products/`, `inventory/`, `clickstream/`, `payments/`

### BRONZE (Delta in Unity Catalog)

- **Purpose:** First structured layer; schema enforcement, minimal parsing.
- **Actions:** Flatten JSON, add audit columns (`_ingestion_ts`, `_source_file`, `_batch_id`), store as Delta.
- **No business logic:** Only parsing and type alignment.

### SILVER (Delta in Unity Catalog)

- **Purpose:** Clean, integrated, business-ready layer.
- **Actions:** Cleansing, deduplication, joins, validation, business keys.
- **Output:** One table per entity (e.g. `orders`, `customers`, `products`) with consistent keys.

### GOLD (Delta in Unity Catalog)

- **Purpose:** Reporting and analytics.
- **Contents:** Fact tables (e.g. `fact_sales`, `fact_orders`), dimensions (customer SCD2, product, store), snapshots (inventory), marts (e.g. daily revenue).

## Security & Governance

- **Unity Catalog:** Catalog per environment (e.g. `retailflow_dev`, `retailflow_prod`); schemas per layer (raw, bronze, silver, gold).
- **Roles:** `raw_ingestion`, `bronze_reader`, `silver_reader`, `gold_reader`, `analytics`, `admin`; least privilege.
- **Secrets:** API keys, DB credentials in Key Vault; Databricks secret scope references Key Vault.
- **Networking:** VNet injection placeholders in Terraform; private endpoints for storage and Databricks.

## Observability

- **Logging:** Structured logs from notebooks/jobs to Azure Monitor.
- **Monitoring:** Job run status, duration, failure alerts.
- **Data quality:** Expectations in DLT or standalone checks (nulls, uniqueness, referential integrity).

## Environment Strategy

- **Dev / Stg / Prod:** Separate configs in `config/environments/`; Terraform workspaces or folders; CI/CD promotes via GitHub Actions.
