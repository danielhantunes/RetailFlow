# RetailFlow — Enterprise Retail Data Platform

Production-grade data platform for a retail company, built on **Azure Databricks** with a **medallion architecture** (RAW → BRONZE → SILVER → GOLD). Processes online orders, store sales, product catalog, inventory, customers, payments, and clickstream events for analytics, BI, and reporting.

> 🚧 **This project is under active development and continuously evolving.** The current state already reflects production-oriented design decisions.

> ⚠️ **This project provisions real cloud resources and may incur costs.** Review the Terraform plan carefully before applying.

---

## Repository structure

```
RetailFlow/
├── config/
│   ├── environments/          # dev, prod config (YAML)
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
│   ├── backend/              # State backend bootstrap (RG, storage, container)
│   ├── base/                 # Layer 1: RG, VNet, Subnets, ADLS Gen2 (retailflowdevdls), Private Endpoint
│   ├── databricks/           # Layer 2: Databricks workspace only (retailflow-dev-dbw, standard)
│   ├── modules/              # Legacy/shared: databricks, storage, key_vault, networking
│   ├── main.tf               # Legacy single-root (optional)
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
├── .github/workflows/         # CI/CD: provision tfstate, deploy notebooks/jobs, promote env, tests
├── .gitignore
└── README.md
```

**CI entry point:** Run [Provision Terraform State Backend (Dev)](.github/workflows/provision-tfstate-dev.yml) first (OIDC). Then [Terraform Base (Dev)](.github/workflows/terraform-base-dev.yml) for base infra, then [Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml) for the workspace. Optionally [Provision Terraform State Backend (Prod)](.github/workflows/provision-tfstate-prod.yml) for separate prod state.

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

See [databricks/notebooks/raw/01_ingest_orders_api.py](databricks/notebooks/raw/01_ingest_orders_api.py): fetches from Orders API, writes one JSON file per run under the RAW path (e.g. `.../data/raw/orders/ingestion_date=YYYY-MM-DD/batch_<id>.json`). No transforms.

---

## Example job config

Main pipeline job: [databricks/jobs/retailflow_main_job.json](databricks/jobs/retailflow_main_job.json). Tasks: ingest RAW (orders, customers) → Bronze → Silver → Gold (fact_orders, dim_customer, daily_revenue_mart). Schedule: daily 02:00 UTC. Concurrency: 1. Cluster: 14.3.x, 2 workers, AQE and Delta optimize enabled.

---

## Terraform

Infrastructure is split into **two layers** so base infra and Databricks can be managed (and destroyed) independently. We use **OIDC + GitHub Actions** for remote state and for running Terraform (no Azure client secret).

- **State backend first:** Run **Provision Terraform State Backend (Dev)** (creates `retailflow-dev-tfstate-rg`, storage `retailflowdevtfstate`). Optionally run **Provision Terraform State Backend (Prod)** for prod. See [terraform/backend/README.md](terraform/backend/README.md).
- **Layer 1 – Base (terraform/base):** Resource group, VNet, subnets, **Azure Data Lake Storage Gen2** (`retailflowdevdls`, hierarchical namespace), private endpoint. Managed by **[Terraform Base (Dev)](.github/workflows/terraform-base-dev.yml)** — action: `plan` \| `apply` \| `destroy`. State: `retailflow-dev-base.tfstate`.
- **Layer 2 – Databricks only (terraform/databricks):** **Azure Databricks Workspace** `retailflow-dev-dbw`, **standard** tier. Depends on base (reads its state). Managed by **[Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml)** — action: `plan` \| `apply` \| `destroy`. State: `retailflow-dev-databricks.tfstate`. Run base first, then this to create the workspace; use destroy on this workflow only to tear down Databricks without touching base.
- **Environments:** Dev and prod only. Prod uses separate state backends and (when added) prod-specific workflows.

---

## CI/CD (GitHub Actions)

All workflows are **manual** (`workflow_dispatch`) unless noted.

### Execution sequence (order matters)

1. **Provision Terraform State Backend (Dev)** — `provision-tfstate-dev.yml`  
   Run once. Creates `retailflow-dev-tfstate-rg`, storage account `retailflowdevtfstate`, container `tfstate`. Required before any Terraform plan/apply.

2. **Terraform Base (Dev)** — `terraform-base-dev.yml`  
   Run with `action: plan`, then `action: apply`. Creates RG, VNet, subnets, ADLS Gen2 (`retailflowdevdls`), private endpoint. Must complete before Layer 2.

3. **Terraform Databricks (Dev)** — `terraform-databricks-dev.yml`  
   Run with `action: plan`, then `action: apply`. Creates workspace `retailflow-dev-dbw` (standard). Depends on base; run after step 2.

4. **After infra is up (any order):** deploy notebooks (`deploy-notebooks.yml`), deploy jobs (`deploy-jobs.yml`), configure secret scope, bootstrap RAW, run pipelines, dbt, monitoring.

**Optional:** Run **Provision Terraform State Backend (Prod)** (`provision-tfstate-prod.yml`) when you need a separate prod state backend; then use prod Terraform workflows (when added) in the same order (base → databricks).

**Tests:** Run `tests.yml` anytime (no dependency on infra).

---

### Workflow reference

- **provision-tfstate-dev.yml:** Dev Terraform state backend. Uses **OIDC**. Run first (step 1).
- **provision-tfstate-prod.yml:** Prod Terraform state backend. Run when you need separate prod state.
- **terraform-base-dev.yml:** Layer 1 – base infra only. Input: `action` (plan \| apply \| destroy). Step 2.
- **terraform-databricks-dev.yml:** Layer 2 – Databricks only. Input: `action` (plan \| apply \| destroy). Step 3.
- **deploy-notebooks.yml:** Sync notebooks to Databricks (e.g. via Repos).
- **deploy-jobs.yml:** Deploy/update Databricks jobs from repo.
- **promote-environment.yml:** Promote to prod or stg (workflow offers both; config + optional Terraform).
- **tests.yml:** Pytest unit tests + Ruff lint.

Workflows live in [.github/workflows/](.github/workflows/).

**Secrets:** Databricks: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. Terraform state backend (OIDC): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. Promote (service principal): `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`.

---

## Unity Catalog and secrets

- Catalogs: `retailflow_dev`, `retailflow_prod` with schemas `raw`, `bronze`, `silver`, `gold`.
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

See [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) for implementation checklist. **First:** run **Provision Terraform State Backend (Dev)**; then **Terraform Base (Dev)** with action `apply`; then **Terraform Databricks (Dev)** with action `apply`. After infra is up: secret scope, RAW bootstrap, run jobs, DLT, dbt, and monitoring.

---

## License

Internal / portfolio use. Adjust org names, endpoints, and secrets for your environment.
