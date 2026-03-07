# RetailFlow — Enterprise Retail Data Platform

Production-grade data platform for a retail company, built on **Azure Databricks** with a **medallion architecture** (RAW → BRONZE → SILVER → GOLD). Gold is served to **Snowflake** for BI (e.g. Power BI). Processes online orders, store sales, product catalog, inventory, customers, payments, and clickstream events for analytics, BI, and reporting. Orchestration: **Airflow**. Transformations and marts: **dbt**.

> 🚧 **This project is under active development and continuously evolving.** The current state already reflects production-oriented design decisions.

> ⚠️ **This project provisions real cloud resources and may incur costs.** Review the Terraform plan carefully before applying.

---

## Repository structure

```
RetailFlow/
├── config/
│   ├── environments/          # dev, stg, prod config (YAML)
│   └── schemas/                # Raw schema references (JSON, e.g. raw_orders.json)
├── databricks/
│   ├── notebooks/
│   │   ├── raw/               # Ingestion: orders, customers, products, inventory, clickstream
│   │   ├── bronze/            # Schema enforcement, audit columns, Delta
│   │   ├── silver/            # Clean, dedup, validation
│   │   ├── gold/              # fact_orders, fact_sales, dim_customer (SCD2), dim_product, dim_store, inventory_snapshot, daily_revenue_mart
│   │   └── observability/     # Job monitoring, logging
│   ├── jobs/                   # (job provisioned via Terraform: terraform/databricks/databricks_resources.tf)
│   └── lib/                    # Shared utilities (see lib/README.md)
├── dlt/
│   └── pipelines/             # Delta Live Tables: Bronze + Silver (orders)
├── airflow/
│   ├── README.md
│   └── dags/                  # Medallion orchestration (trigger Databricks job)
├── dbt/
│   └── retailflow/            # Marts and transformations (e.g. daily_revenue)
│       └── models/marts/      # daily_revenue.sql, sources.yml
├── terraform/
│   ├── backend/              # State backend bootstrap (RG, storage, container)
│   ├── base/                 # Layer 1: RG, VNet, subnets (Databricks, Postgres, bootstrap VM), ADLS Gen2, NSGs
│   ├── databricks/           # Layer 2: Databricks workspace (retailflow-dev-dbw, standard)
│   ├── postgres/             # Optional: Olist PostgreSQL Flexible Server (private, base VNet)
│   ├── modules/              # Legacy/shared: databricks, storage, key_vault, networking
│   ├── main.tf               # Legacy single-root (optional)
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── sql/                       # Olist table DDL (create_tables.sql)
├── databaseinput/            # Brazilian E-Commerce (Olist) dataset ZIP
├── scripts/                   # Bootstrap RAW, secret scope, Olist runner install & load (load_olist.sh, install_github_runner.sh)
├── tests/
│   ├── unit/
│   └── requirements.txt
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COMPUTE_AND_COST.md
│   ├── DATA_FLOW.md
│   ├── DATABRICKS_AZURE_AUTH.md
│   ├── NEXT_STEPS.md
│   ├── RAW_LAYER_DESIGN.md
│   ├── REPOSITORY_TREE.md
│   ├── UNITY_CATALOG.md
│   └── OBSERVABILITY.md
├── .github/workflows/         # CI/CD: provision tfstate, terraform base/databricks, deploy notebooks/jobs, promote env, tests
├── .gitignore
└── README.md
```

**CI entry point:** Run [Provision Terraform State Backend (Dev)](.github/workflows/provision-tfstate-dev.yml) first (OIDC). Then [Terraform Base (Dev)](.github/workflows/terraform-base-dev.yml) for base infra, then [Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml) for the workspace. Optionally [Provision Terraform State Backend (Prod)](.github/workflows/provision-tfstate-prod.yml) for separate prod state.

---

## Architecture (summary)

- **RAW:** ADLS Gen2; immutable; partition by `ingestion_date`; JSON/CSV/Parquet as received. Supports replay and schema evolution.
- **Bronze:** Delta in Unity Catalog; minimal parsing, flatten JSON, audit columns (`_ingestion_ts`, `_source_file`).
- **Silver:** Delta; cleaned, deduplicated, validated, business keys.
- **Gold:** Delta; reporting-ready: `fact_orders`, `fact_sales`, `dim_customer` (SCD2), `dim_product`, `dim_store`, inventory snapshot, `daily_revenue_mart`. Gold is synced or exposed to **Snowflake** as the serving layer for Power BI and analytics.
- **Serving:** **Snowflake** (gold layer); Power BI, Tableau, and SQL clients consume from Snowflake.

Tech: **Azure Databricks**, **Delta Lake**, **Unity Catalog**, **ADLS Gen2**, **Snowflake** (gold serving), **Airflow** (orchestration), **dbt** (marts), **Azure Key Vault**, **Azure Monitor**, **Terraform**, **GitHub Actions**.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATA_FLOW.md](docs/DATA_FLOW.md), [docs/RAW_LAYER_DESIGN.md](docs/RAW_LAYER_DESIGN.md).

---

## Data flow

1. **Ingestion** (notebooks) → RAW on ADLS (`/data/raw/orders`, `customers`, `products`, `inventory`, `clickstream`, etc.).
2. **Bronze** notebooks/DLT read RAW → parse, add audit columns → Delta tables in Bronze schema.
3. **Silver** reads Bronze → clean, dedupe, validate → Delta in Silver schema.
4. **Gold** reads Silver → facts, dimensions, marts → Delta in Gold schema (dbt + notebooks).
5. **Serving:** Gold is synced or exposed to **Snowflake**; **Airflow** orchestrates the medallion pipeline.
6. **Consumption:** Power BI, Tableau, and SQL clients query **Snowflake** (gold); Databricks SQL can query Gold in the lake as needed.

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

Main pipeline job **RetailFlow_Main_Pipeline** is defined and provisioned in Terraform: [terraform/databricks/databricks_resources.tf](terraform/databricks/databricks_resources.tf). Tasks: ingest RAW (orders, customers) → Bronze → Silver → Gold (fact_orders, dim_customer, daily_revenue_mart). Schedule: daily 02:00 UTC. Concurrency: 1. Cluster: LTS with Photon, Standard_D4as_v5, autoscale 1–2 workers, AQE and Delta optimize enabled (job cluster terminates after run). See [docs/COMPUTE_AND_COST.md](docs/COMPUTE_AND_COST.md) for DEV/PROD compute sizing and cost guidance.

---

## Terraform

**Default region:** All resources (state backend, base, Databricks, optional PostgreSQL) use **East US 2** by default to avoid subscription restrictions (e.g. `LocationIsOfferRestricted` for PostgreSQL in East US). Override via workflow inputs or Terraform variables if needed.

Infrastructure is split into **two layers** so base infra and Databricks can be managed (and destroyed) independently. We use **OIDC + GitHub Actions** for remote state and for running Terraform (no Azure client secret).

- **State backend first:** Run **Provision Terraform State Backend (Dev)** (creates `retailflow-dev-tfstate-rg`, storage `retailflowdevtfstate`). Optionally run **Provision Terraform State Backend (Prod)** for prod. See [terraform/backend/README.md](terraform/backend/README.md).
- **Layer 1 – Base (terraform/base):** Resource group, VNet, subnets (Databricks, optional Postgres delegated subnet, bootstrap VM), **Azure Data Lake Storage Gen2** (`retailflowdevdls`) with containers **raw, bronze, silver, gold**, private endpoint. Managed by **[Terraform Base (Dev)](.github/workflows/terraform-base-dev.yml)** — action: `plan` \| `apply` \| `destroy`. State: `retailflow-dev-base.tfstate`.
- **Layer 2 – Databricks only (terraform/databricks):** **Azure Databricks Workspace** `retailflow-dev-dbw` (standard), **dev cluster** (single-node, 30 min auto-terminate), and **main pipeline job** (RetailFlow_Main_Pipeline with job cluster 1–2 workers). Depends on base. Managed by **[Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml)** — action: `plan` \| `apply` \| `destroy`. Databricks auth: **Azure AD** (same service principal as Azure; see [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md)). State: `retailflow-dev-databricks.tfstate`. **Apply order:** base first, then this. **Destroy order:** run Databricks destroy first, then base destroy.
- **Optional – Olist PostgreSQL (terraform/postgres):** Private Azure Database for PostgreSQL Flexible Server in base VNet (same region as base). Bootstrap VM runner loads Brazilian E-Commerce (Olist) CSVs via `provision_olist_postgres.yml`. State: `retailflow-ingest-pg.tfstate`. Run after base.
- **Environments:** Dev and prod only. Prod uses separate state backends and (when added) prod-specific workflows.

---

## CI/CD (GitHub Actions)

All workflows are **manual** (`workflow_dispatch`) unless noted.

### Execution sequence (order matters)

1. **Provision Terraform State Backend (Dev)** — `provision-tfstate-dev.yml`  
   Run once. Creates `retailflow-dev-tfstate-rg`, storage account `retailflowdevtfstate`, container `tfstate`. Required before any Terraform plan/apply.

2. **Terraform Base (Dev)** — `terraform-base-dev.yml`  
   Run with `action: plan`, then `action: apply`. Creates RG, VNet, subnets (with NSGs for Databricks), ADLS Gen2 (`retailflowdevdls`) with containers **raw, bronze, silver, gold**, private endpoint. Must complete before Layer 2.

3. **Terraform Databricks (Dev)** — `terraform-databricks-dev.yml`  
   Run with `action: plan`, then `action: apply`. Creates workspace `retailflow-dev-dbw`, dev cluster (`retailflow-dev-single-node`), and job `RetailFlow_Main_Pipeline`. Depends on base; run after step 2. **Secrets:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `ARM_CLIENT_SECRET`, `AZURE_PRINCIPAL_ID` (Object ID of the service principal; Terraform grants Contributor on the workspace). See [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md).

4. **After infra is up (any order):** deploy notebooks (`deploy-notebooks.yml`), deploy jobs (`deploy-jobs.yml`), configure secret scope, bootstrap RAW, run Airflow DAGs, dbt marts, sync Gold to Snowflake (when configured), monitoring.

**Olist PostgreSQL (optional):** Single workflow **Provision PostgreSQL for Olist** (`provision_olist_postgres.yml`). Add **`GH_PAT`** for runner registration. **action:** `plan` \| `apply` \| `destroy` (Terraform only); **`full`** = apply + register + load (no `POSTGRES_*`); **`register_only`** = install runner (needs **GH_PAT**); **`bootstrap_only`** = load CSVs only — connection from Terraform state (no `POSTGRES_*` if you ran `apply` first). **Sequence:** plan → apply → register_only → bootstrap_only → destroy. Run after Terraform Base (Dev). **If you get `LocationIsOfferRestricted`** for PostgreSQL: your subscription may restrict that region; [request a quota increase](https://aka.ms/postgres-request-quota-increase) or ensure the base layer is in an allowed region (default: **East US 2**).

**Optional:** Run **Provision Terraform State Backend (Prod)** (`provision-tfstate-prod.yml`) when you need a separate prod state backend; then use prod Terraform workflows (when added) in the same order (base → databricks).

**Tests:** Run `tests.yml` anytime (no dependency on infra).

**Destroy (tear down all infra):** Run **Terraform Databricks (Dev)** with `action: destroy` first, then **Terraform Base (Dev)** with `action: destroy`. Order matters (Databricks depends on base). To remove Olist Postgres only, run **Provision PostgreSQL for Olist** with `action: destroy`.

---

### Workflow reference

- **provision-tfstate-dev.yml:** Dev Terraform state backend. Uses **OIDC**. Run first (step 1).
- **provision-tfstate-prod.yml:** Prod Terraform state backend. Run when you need separate prod state.
- **terraform-base-dev.yml:** Layer 1 – base infra only. Input: `action` (plan \| apply \| destroy). Step 2.
- **terraform-databricks-dev.yml:** Layer 2 – workspace, dev cluster, main pipeline job. Databricks: **Azure AD** (same service principal + `ARM_CLIENT_SECRET`). Input: `action` (plan \| apply \| destroy). Step 3.
- **deploy-notebooks.yml:** Sync notebooks to Databricks (e.g. via Repos).
- **deploy-jobs.yml:** Deploy/update Databricks jobs from repo.
- **promote-environment.yml:** Promote to prod or stg (workflow offers both; config + optional Terraform).
- **tests.yml:** Pytest unit tests + Ruff lint.
- **provision_olist_postgres.yml:** Single Olist workflow. **action:** `plan` \| `apply` \| `destroy` \| **`full`** (apply + register + load; no `POSTGRES_*`) \| **`register_only`** (install runner; **GH_PAT**) \| **`bootstrap_only`** (load data; connection from Terraform state after `apply` — no `POSTGRES_*` needed). Sequence: plan → apply → register_only → bootstrap_only → destroy. Run after Terraform Base (Dev).

Workflows live in [.github/workflows/](.github/workflows/).

**Secrets:** Terraform Azure (OIDC): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (passed as `ARM_*`). Terraform Databricks (Azure AD): same app + `ARM_CLIENT_SECRET` and `AZURE_PRINCIPAL_ID` (Object ID of the service principal; used to grant Contributor on the workspace via Terraform). See [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md). Optional (deploy-notebooks/jobs): `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. Promote: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`. **Olist:** **`GH_PAT`** for `full` and `register_only`. **`POSTGRES_*`** optional for `bootstrap_only` (used only if Terraform state has no outputs).

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

See [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) for implementation checklist. **First:** run **Provision Terraform State Backend (Dev)**; then **Terraform Base (Dev)** with action `apply`; then **Terraform Databricks (Dev)** with action `apply`. After infra is up: secret scope, RAW bootstrap, run jobs, Airflow DAGs, DLT, dbt marts, Snowflake gold serving, and monitoring.

---

## License

Internal / portfolio use. Adjust org names, endpoints, and secrets for your environment.
