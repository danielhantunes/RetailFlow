# RetailFlow — Enterprise Retail Data Platform

Production-grade data platform for a retail company, built on **Azure Databricks** with a **medallion architecture** (RAW → BRONZE → SILVER → GOLD). Processes online orders, store sales, product catalog, inventory, customers, payments, and clickstream events for analytics, BI, and reporting.

> 🚧 **This project is under active development and continuously evolving.** The current state already reflects production-oriented design decisions.

---

## Repository structure

```
RetailFlow/
├── config/
│   ├── environments/          # dev, stg, prod config (YAML)
│   └── schemas/               # Raw schema references (JSON)
├── databricks/
│   ├── notebooks/
│   │   ├── raw/               # Ingestion: orders, customers, products, inventory, clickstream
│   │   ├── bronze/            # Schema enforcement, audit columns, Delta
│   │   ├── silver/            # Clean, dedup, validation
│   │   ├── gold/              # fact_orders, fact_sales, dim_customer (SCD2), dim_product, daily_revenue_mart
│   │   └── observability/     # Job monitoring, logging
│   └── jobs/                  # Job definition JSON (RetailFlow_Main_Pipeline)
├── dlt/
│   └── pipelines/             # Delta Live Tables: Bronze + Silver (orders)
├── airflow/
│   └── dags/                  # Optional: medallion DAG (trigger Databricks job)
├── dbt/
│   └── retailflow/            # Optional: marts (e.g. daily_revenue)
├── terraform/
│   ├── modules/
│   │   ├── databricks/        # Workspace
│   │   ├── storage/          # ADLS Gen2 (raw, processed)
│   │   ├── key_vault/        # Secrets
│   │   └── networking/       # VNet placeholders
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
├── scripts/                   # Bootstrap RAW folders, secret scope
├── tests/
│   ├── unit/
│   └── requirements.txt
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_FLOW.md
│   ├── RAW_LAYER_DESIGN.md
│   ├── UNITY_CATALOG.md
│   └── OBSERVABILITY.md
├── .github/workflows/         # CI/CD: deploy notebooks, jobs, promote env, tests
├── .gitignore
└── README.md
```

---

## Architecture (summary)

- **RAW:** ADLS Gen2; immutable; partition by `ingestion_date`; JSON/CSV/Parquet as received. Supports replay and schema evolution.
- **Bronze:** Delta in Unity Catalog; minimal parsing, flatten JSON, audit columns (`_ingestion_ts`, `_source_file`).
- **Silver:** Delta; cleaned, deduplicated, validated, business keys.
- **Gold:** Delta; reporting-ready: `fact_sales`, `fact_orders`, `dim_customer` (SCD2), `dim_product`, store dimension, inventory snapshot, `daily_revenue_mart`.

Tech: **Azure Databricks**, **Delta Lake**, **Unity Catalog**, **ADLS Gen2**, **Azure Key Vault**, **Azure Monitor**, **Terraform**, **GitHub Actions**, optional **Airflow** and **dbt**.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATA_FLOW.md](docs/DATA_FLOW.md), [docs/RAW_LAYER_DESIGN.md](docs/RAW_LAYER_DESIGN.md).

---

## Data flow

1. **Ingestion** (notebooks) → RAW on ADLS (`/data/raw/orders`, `customers`, `products`, `inventory`, `clickstream`, etc.).
2. **Bronze** notebooks/DLT read RAW → parse, add audit columns → Delta tables in Bronze schema.
3. **Silver** reads Bronze → clean, dedupe, validate → Delta in Silver schema.
4. **Gold** reads Silver → facts, dimensions, marts → Delta in Gold schema.
5. **Consumption:** Power BI, Tableau, Databricks SQL on Gold (and Silver as needed).

---

## RAW layer design

- **Immutability:** Append-only; no updates/deletes.
- **Exact copy:** No transformations; store payload as-is.
- **Partitioning:** `ingestion_date=YYYY-MM-DD`.
- **Replay:** Reprocess any date range from RAW without changing RAW.
- **Metadata:** Ingestion timestamp and source file captured in Bronze when reading RAW.

Details: [docs/RAW_LAYER_DESIGN.md](docs/RAW_LAYER_DESIGN.md).

---

## Example notebook (RAW orders)

See [databricks/notebooks/raw/01_ingest_orders_api.py](databricks/notebooks/raw/01_ingest_orders_api.py): fetches from Orders API, writes one JSON file per run under `raw_base/ingestion_date=YYYY-MM-DD/batch_<id>.json`. No transforms.

---

## Example job config

Main pipeline job: [databricks/jobs/retailflow_main_job.json](databricks/jobs/retailflow_main_job.json). Tasks: ingest RAW (orders, customers) → Bronze → Silver → Gold (fact_orders, dim_customer, daily_revenue_mart). Schedule: daily 02:00 UTC. Concurrency: 1. Cluster: 14.3.x, 2 workers, AQE and Delta optimize enabled.

---

## Terraform

- **Root:** `main.tf` wires resource group, Databricks module, storage, Key Vault, optional networking.
- **Modules:** `databricks` (workspace), `storage` (ADLS Gen2, containers `raw`/`processed`), `key_vault`, `networking` (VNet/subnets).
- **Backend:** Configure `backend "azurerm"` (e.g. state in Azure Storage).
- **Environments:** Use `terraform.tfvars` or workspaces for dev/stg/prod; see `terraform.tfvars.example`.

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

---

## CI/CD (GitHub Actions)

- **deploy-notebooks.yml:** On push to `main` (databricks/notebooks, dlt) — sync notebooks (e.g. via Repos).
- **deploy-jobs.yml:** On push to job definitions — deploy/update Databricks jobs via API.
- **promote-environment.yml:** Manual; promote to stg or prod (config + optional Terraform).
- **tests.yml:** Pytest unit tests + Ruff lint on push/PR.

Secrets: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`; for Terraform: `ARM_*`.

---

## Unity Catalog and secrets

- Catalogs: `retailflow_dev`, `retailflow_stg`, `retailflow_prod` with schemas `raw`, `bronze`, `silver`, `gold`.
- Roles: raw_ingestion, bronze_reader, silver_reader, gold_reader, analytics, platform_admin.
- Secret scope: Azure Key Vault–backed scope (e.g. `retailflow-keyvault`) for API keys and DB connection strings.

See [docs/UNITY_CATALOG.md](docs/UNITY_CATALOG.md).

---

## Observability

- Logging and job run metadata: [databricks/notebooks/observability/job_monitor.py](databricks/notebooks/observability/job_monitor.py).
- Alerts: Databricks job failure emails; optional Azure Monitor.
- Data quality: DLT expectations in [dlt/pipelines/bronze_silver_dlt.py](dlt/pipelines/bronze_silver_dlt.py).

See [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md).

---

## Next steps

See [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) for implementation checklist: Terraform apply, secret scope, RAW bootstrap, run jobs, DLT, dbt, and monitoring.

---

## License

Internal / portfolio use. Adjust org names, endpoints, and secrets for your environment.
