# RetailFlow — Enterprise Retail Data Platform

Production-grade data platform for a retail company, built on **Azure Databricks** with a **medallion architecture** (RAW → BRONZE → SILVER → GOLD). **Source system (current):** **Azure PostgreSQL** (e.g. Olist) → **Azure Function** → ADLS RAW; downstream Bronze/Silver/Gold consume that path. Sample **REST/CSV** notebooks exist for demos and alternate layouts but are not the primary operational source. Gold is served to **Snowflake** for BI (e.g. Power BI). **Implemented:** Bronze for default Postgres tables, Silver for orders/customers, a **subset of Gold** in the main Terraform job (other Gold notebooks for extension). Orchestration: **Airflow** (optional; Databricks jobs are primary in CI). Transformations and marts: **dbt**.

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
│   │   ├── bronze/            # RAW→Delta: orders, customers, products, order_items, payments, reviews, sellers, geolocation (see docs/REPOSITORY_TREE.md)
│   │   ├── silver/            # Clean, dedup, validation
│   │   ├── gold/              # fact/dim/mart notebooks; main job runs fact_orders, dim_customer, daily_revenue (see terraform/databricks/databricks_resources.tf)
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
│   ├── base/                 # Layer 1 (platform): RG, VNet, subnets, NSGs, Postgres DNS (no ADLS; no bootstrap VM)
│   ├── bootstrap_vm/         # On-demand toolbox VM (separate state)
│   ├── adls/                 # ADLS Gen2 retailflowdevdls (separate state)
│   ├── databricks_workspace/ # Layer 2a: Azure Databricks workspace (RM only; long-lived state)
│   ├── databricks/           # Layer 2b: clusters + jobs (compute; separate state; destroy without losing workspace)
│   ├── postgres/             # Optional: Olist PostgreSQL Flexible Server (private, base VNet)
│   ├── postgres_ingest_function/  # Azure Function: Postgres → ADLS RAW (after Platform + Data Lake + Postgres)
│   ├── bastion/              # Optional: Azure Bastion Standard (run after base; destroy when idle to save cost)
│   ├── modules/              # Legacy/shared: databricks, storage, key_vault, networking
│   ├── main.tf               # Legacy single-root (optional)
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── functions/
│   └── postgres_to_raw/      # Azure Function (timer + HTTP): Postgres → ADLS RAW ingestion
├── sql/                       # Olist table DDL (create_tables.sql)
├── databaseinput/            # Brazilian E-Commerce (Olist) dataset ZIP
├── scripts/                   # Bootstrap RAW, secret scope, Olist runner install & load (load_olist.sh, install_github_runner.sh), toolbox (toolbox_setup.sh, toolbox_psql_examples.sh, toolbox_inspect_postgres.py)
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
│   ├── BASTION.md             # Azure Bastion (Standard) on-demand browser SSH
│   ├── TOOLBOX.md             # Toolbox on bootstrap VM (psql, Python); Bastion + Entra to connect
│   ├── UNITY_CATALOG.md
│   └── OBSERVABILITY.md
├── .github/workflows/         # CI/CD: tfstate, platform/data-lake/bootstrap-vm/databricks-workspace+databricks-compute, bastion, olist postgres, postgres ingest fn, deploy, promote, tests
├── .gitignore
└── README.md
```

**CI entry point:** Run [Provision Terraform State Backend (Dev)](.github/workflows/provision-tfstate-dev.yml) first (OIDC). Then [Terraform Platform (Dev)](.github/workflows/terraform-platform-dev.yml), [Terraform Data Lake (Dev)](.github/workflows/terraform-data-lake-dev.yml) for ADLS, optionally [Terraform Bootstrap VM (Dev)](.github/workflows/terraform-bootstrap-vm-dev.yml) for the toolbox VM, then [Terraform Databricks Workspace (Dev)](.github/workflows/terraform-databricks-workspace-dev.yml) for the Azure workspace, then [Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml) for clusters and jobs. Optionally [Provision Terraform State Backend (Prod)](.github/workflows/provision-tfstate-prod.yml) for separate prod state.

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

## Target data flow

The platform is designed around this end-to-end flow (e.g. for Olist / retail data):

```
PostgreSQL (source, e.g. Olist)
      │
      ▼
Azure Function  (timer + HTTP for manual/CI)  →  reads Postgres, writes to RAW
      │
      ▼
ADLS RAW  (immutable, partition by ingestion_date)
      │
      ▼
Databricks  Bronze → Silver  (Delta, Unity Catalog)
      │
      ▼
Snowflake  (Gold layer / serving)
      │
      ▼
dbt models  (marts, transformations)
      │
      ▼
Analytics marts  (Power BI, Tableau, reporting)
```

- **PostgreSQL:** Operational source (e.g. Azure PostgreSQL with Olist data). Provisioned via Terraform; initial load via `provision_olist_postgres.yml`.
- **Scheduled ingestion:** An **Azure Function** (Postgres → RAW) runs on a **timer** (e.g. every 15 min), reads from Postgres (query-based), and writes **JSONL** under **`postgres_ingest/`** in the RAW ADLS filesystem (see [docs/DATA_FLOW.md](docs/DATA_FLOW.md#postgres-azure-function-to-raw)). **Manual / CI runs** call **`POST /api/postgres_ingest_run`** (host key; **`GET`** is a lightweight health check) via **Run Postgres RAW Initial Load** / **Incremental** after setting `INGESTION_MODE`. Provision via **Provision Postgres Ingest Function** (run after Platform, Data Lake, and Postgres).
- **VM toolbox:** The bootstrap VM is used for **one-time or ad-hoc loads** (e.g. initial Olist CSV load) and **inspecting Postgres** (psql, Python scripts). It is not used for scheduled ingestion. See [docs/TOOLBOX.md](docs/TOOLBOX.md).
- **RAW → Bronze → Silver:** Databricks notebooks/DLT; Gold is then synced or exposed to **Snowflake** for serving; **dbt** builds marts on Gold.

---

## Data flow (detail)

1. **Source → RAW:** **PostgreSQL is the current source system** for scheduled ingestion: an **Azure Function** (timer + optional HTTP trigger) reads from Postgres and writes to ADLS RAW under **`postgres_ingest/`** (see [docs/DATA_FLOW.md](docs/DATA_FLOW.md)). The **VM toolbox** is for one-time/ad-hoc loads and inspection only. Optional sample notebooks (REST APIs, CSVs) can write other RAW prefixes for development; production paths follow **`postgres_ingest/`** from Postgres.
2. **Bronze** notebooks/DLT read RAW → parse, add audit columns → Delta tables in Bronze schema.
3. **Silver** reads Bronze → clean, dedupe, validate → Delta in Silver schema.
4. **Gold** reads Silver → facts, dimensions, marts → Delta in Gold schema (dbt + notebooks). Gold is synced or exposed to **Snowflake**.
5. **Serving:** **Snowflake** holds the Gold layer; **Airflow** orchestrates the medallion pipeline.
6. **Consumption:** **dbt** models run on Gold; Power BI, Tableau, and SQL clients query **Snowflake** (gold) or Databricks for analytics marts.

---

## RAW layer design

- **Immutability:** Append-only; no updates/deletes.
- **Exact copy:** No transformations; store payload as-is.
- **Partitioning:** `ingestion_date=YYYY-MM-DD` (Postgres function also uses `hour=` and `batch_id=` in the path).
- **Replay:** Reprocess any date range from RAW without changing RAW.
- **Metadata:** Ingestion timestamp and source file captured in Bronze when reading RAW.
- **Config sample:** `config/environments/dev.yaml` defaults **`storage.account_name`** / **`base_path`** to **`retailflowdevdls`**, matching **`terraform/adls`** for dev. Override if your storage account name differs. Point Databricks `abfss://` paths and Spark config (`retailflow.storage_account`, etc.) at the account you deployed.

Details: [docs/RAW_LAYER_DESIGN.md](docs/RAW_LAYER_DESIGN.md).

---

## Example notebook (RAW orders)

See [databricks/notebooks/raw/01_ingest_orders_api.py](databricks/notebooks/raw/01_ingest_orders_api.py): fetches from Orders API, writes one JSON file per run under the RAW path (e.g. `.../data/raw/orders/ingestion_date=YYYY-MM-DD/batch_<id>.json`). No transforms.

---

## Example job config

Main pipeline job **RetailFlow_Main_Pipeline** is defined and provisioned in Terraform: [terraform/databricks/databricks_resources.tf](terraform/databricks/databricks_resources.tf). Tasks: optional **RAW sample ingest** (orders + customers API notebooks) → **Bronze** (reads **`postgres_ingest/`** for orders, customers, products, order_items, order_payments, order_reviews, sellers, geolocation; Bronze tasks after both RAW ingests) → **Silver** (orders, customers) → **Gold** (fact_orders, dim_customer, daily_revenue_mart). **Operational data** is expected from **PostgreSQL → RAW**; API tasks are supplementary. Schedule: daily 02:00 UTC. Concurrency: 1. Cluster: LTS with Photon, Standard_D4as_v5, autoscale 1–2 workers, AQE and Delta optimize enabled (job cluster terminates after run). See [docs/COMPUTE_AND_COST.md](docs/COMPUTE_AND_COST.md) for DEV/PROD compute sizing and cost guidance.

---

## Terraform

**Default region:** All resources (state backend, base, Databricks, optional PostgreSQL) use **East US 2** by default to avoid subscription restrictions (e.g. `LocationIsOfferRestricted` for PostgreSQL in East US). Override via workflow inputs or Terraform variables if needed.

The **primary** split is **Layer 1 (platform)** vs **Layer 2 (Databricks)**. Layer 2 is further split: **`terraform/databricks_workspace`** (Azure RM workspace + SP Contributor) and **`terraform/databricks`** (cluster + jobs only) so you can **`terraform destroy` compute** while keeping the workspace and notebooks. **ADLS** and the **bootstrap VM** use separate states for lifecycle control. **Optional** Terraform states (Bastion, Postgres, Postgres ingest function) sit beside that split. We use **OIDC + GitHub Actions** for Terraform in CI (no client secret for those OIDC workflows).

- **State backend first:** Run **Provision Terraform State Backend (Dev)** (creates `retailflow-dev-tfstate-rg`, storage `retailflowdevtfstate`). Optionally run **Provision Terraform State Backend (Prod)** for prod. See [terraform/backend/README.md](terraform/backend/README.md).
- **Layer 1 – Platform (terraform/base):** Resource group, VNet, subnets (Databricks, Postgres delegated, private endpoints), NSGs, Postgres private DNS. **No** ADLS, **no** bootstrap VM. Managed by **[Terraform Platform (Dev)](.github/workflows/terraform-platform-dev.yml)** — `plan` \| `apply` \| `destroy`. State: `retailflow-dev-base.tfstate`.
- **Data Lake (terraform/adls):** ADLS Gen2 `retailflowdevdls`, filesystems **raw, bronze, silver, gold**, optional blob private endpoint. Separate state: **[Terraform Data Lake (Dev)](.github/workflows/terraform-data-lake-dev.yml)** (`retailflow-dev-adls.tfstate`). Run after Platform apply.
- **Bootstrap VM (terraform/bootstrap_vm):** On-demand toolbox / Olist runner VM. **[Terraform Bootstrap VM (Dev)](.github/workflows/terraform-bootstrap-vm-dev.yml)** — apply when needed, destroy to save cost. State: `retailflow-dev-bootstrap-vm.tfstate`. Requires Platform applied first.
- **Optional – Bastion (terraform/bastion):** Azure Bastion (**Standard**) for browser SSH to the private bootstrap VM. Run **after** Platform, **Bootstrap VM**, and (for RBAC) Data Lake as needed. **Destroy when idle.** Managed by **[Terraform Bastion (Dev)](.github/workflows/terraform-bastion-dev.yml)**. State: `retailflow-dev-bastion.tfstate`. **Before destroying platform networking**, destroy Bastion if it exists.
- **Layer 2a – Databricks workspace (`terraform/databricks_workspace`):** Azure RM workspace `retailflow-dev-dbw` (Standard, VNet-injected) and optional **Contributor** for the CI service principal. State: **`retailflow-dev-databricks-workspace.tfstate`**. **[Terraform Databricks Workspace (Dev)](.github/workflows/terraform-databricks-workspace-dev.yml)**. Run after Platform.
- **Layer 2b – Databricks compute (`terraform/databricks`):** Dev cluster and job **RetailFlow_Main_Pipeline**; reads workspace outputs from Layer 2a remote state. State: **`retailflow-dev-databricks-compute.tfstate`**. **[Terraform Databricks (Dev)](.github/workflows/terraform-databricks-dev.yml)**. Run after Layer 2a. **Destroy compute** here to drop job/cluster cost **without** deleting the workspace; destroy the workspace stack only when you intend to remove the workspace entirely.
- **Apply order:** Platform → (Data Lake, optional VM) → **Databricks Workspace** → **Databricks (compute)**. **Teardown (typical):** **Databricks (compute)** destroy → optional Bastion / Postgres / etc. → **Databricks Workspace** destroy (if removing workspace) → Data Lake → Platform last.
- **Optional – Olist PostgreSQL (terraform/postgres):** Private PostgreSQL Flexible Server in the platform VNet. Bootstrap VM (when applied) loads Olist CSVs via `provision_olist_postgres.yml`. State: `retailflow-ingest-pg.tfstate`. Run after Platform.
- **Optional – Postgres Ingest Function (terraform/postgres_ingest_function):** Timer + HTTP Postgres → ADLS RAW. Run **after** Platform, **Data Lake**, and Postgres (apply). Managed by **Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`). State: `retailflow-postgres-ingest-function.tfstate`. See [terraform/postgres_ingest_function/README.md](terraform/postgres_ingest_function/README.md) for deploy behavior and **Python v2** app settings.
- **When PostgreSQL is your source-of-origin:** Run **Provision PostgreSQL for Olist** before the ingest function. Recommended order: **Platform → Data Lake → Postgres → Postgres Ingest Function** (VM/Bootstrap when loading CSVs).
- **Environments:** Dev and prod only. Prod uses separate state backends and (when added) prod-specific workflows.

---

## CI/CD (GitHub Actions)

All workflows are **manual** (`workflow_dispatch`) unless noted.

### Execution sequence (order matters)

1. **Provision Terraform State Backend (Dev)** — `provision-tfstate-dev.yml`  
   Run once. Creates `retailflow-dev-tfstate-rg`, storage account `retailflowdevtfstate`, container `tfstate`. Required before any Terraform plan/apply.

2. **Terraform Platform (Dev)** — `terraform-platform-dev.yml`  
   `plan` then `apply`. Creates RG, VNet, subnets (Databricks, Postgres, PE), NSGs, Postgres private DNS.

3. **Terraform Data Lake (Dev)** — `terraform-data-lake-dev.yml`  
   `plan` then `apply`. Creates ADLS Gen2 `retailflowdevdls`, filesystems **raw, bronze, silver, gold**, optional private endpoint.

4. **Terraform Bootstrap VM (Dev)** (optional, on-demand) — `terraform-bootstrap-vm-dev.yml`  
   Apply when you need the toolbox/Olist runner VM; destroy when idle.

5. **Terraform Databricks Workspace (Dev)** — `terraform-databricks-workspace-dev.yml`  
   `plan` then `apply`. Azure Databricks workspace `retailflow-dev-dbw` and optional SP **Contributor** on the workspace. Run after Platform (step 2). **Secrets:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_PRINCIPAL_ID`. **OIDC only.** See [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md).

6. **Terraform Databricks (Dev)** — `terraform-databricks-dev.yml`  
   `plan` then `apply`. Dev cluster and job `RetailFlow_Main_Pipeline` (reads workspace from remote state). Run after step 5. Same OIDC secrets as step 5.

7. **After infra is up (any order):** deploy notebooks (`deploy-notebooks.yml`), deploy jobs (`deploy-jobs.yml`), configure secret scope, bootstrap RAW, run Airflow DAGs, dbt marts, sync Gold to Snowflake (when configured), monitoring.

- **Azure Bastion (optional, on-demand):** **Terraform Bastion (Dev)** — `terraform-bastion-dev.yml`. Run **after** Platform, **Bootstrap VM** (if using SSH), and Data Lake as needed. **Destroy** when done.

- **Olist PostgreSQL (optional):** **Provision PostgreSQL for Olist** (`provision_olist_postgres.yml`). **After Terraform Platform (Dev)** — Postgres reads platform state. **Apply Terraform Bootstrap VM (Dev)** before **register_only** / **bootstrap_only** if you use the runner on that VM. **If Databricks ingests from Postgres:** Platform → Postgres (load data) → Databricks. **`GH_PAT`** for runner registration. **action:** `plan` \| `apply` \| `destroy` \| **`full`** \| **`register_only`** \| **`bootstrap_only`**. See [docs/TOOLBOX.md](docs/TOOLBOX.md).

- **Postgres Ingest Function (optional):** **Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`). Run **after** Platform, **Data Lake**, and Postgres (apply). On **apply**, Terraform + **zip deploy** (`az webapp deploy`, longer timeout than legacy `config-zip`; see module README). Code: `functions/postgres_to_raw`.
After provisioning, ingestion cadence is controlled by the timer (`POSTGRES_TIMER_SCHEDULE`, default every 15 minutes). **Ad-hoc runs:** **Run Postgres RAW Initial Load** / **Incremental** set `INGESTION_MODE` and invoke **`POST .../api/postgres_ingest_run`** with the **host master key** (workflows **GET**-probe first to catch missing deploys).
The function writes chunked JSONL under **`postgres_ingest/`**, checkpoints in **`_control/postgres_watermarks`**, and run manifests in **`postgres_ingest/_runs`**, enabling restart-safe continuation after interrupted runs. `host.json` sets a long **`functionTimeout`** so initial loads can finish over HTTP.

- **Optional:** **Provision Terraform State Backend (Prod)** (`provision-tfstate-prod.yml`) for prod state.

- **Tests:** Run `tests.yml` anytime.

- **Destroy (full teardown):** **Terraform Databricks (Dev)** `destroy` (compute only; keeps workspace) → **Terraform Bastion (Dev)** `destroy` (if used) → **Provision Postgres Ingest Function** `destroy` → **Provision PostgreSQL for Olist** `destroy` (if used) → **Terraform Bootstrap VM (Dev)** `destroy` → **Terraform Data Lake (Dev)** `destroy` → **Terraform Databricks Workspace (Dev)** `destroy` (removes workspace; run after compute destroy) → **Terraform Platform (Dev)** `destroy`. Order matters for dependencies.

---

### Workflow reference

- **provision-tfstate-dev.yml:** Dev Terraform state backend. Uses **OIDC**. Run first (step 1).
- **provision-tfstate-prod.yml:** Prod Terraform state backend. Run when you need separate prod state.
- **terraform-platform-dev.yml:** Layer 1 – platform (RG, VNet, subnets, NSGs, Postgres DNS). Input: `action` (plan \| apply \| destroy). Step 2.
- **terraform-data-lake-dev.yml:** ADLS Gen2 `retailflowdevdls`. Input: `action` (plan \| apply \| destroy). Step 3.
- **terraform-bootstrap-vm-dev.yml:** On-demand toolbox VM. Input: `action` (plan \| apply \| destroy). Step 4 (optional).
- **terraform-bastion-dev.yml:** Optional Bastion (**Standard**). After Platform + Bootstrap VM. Input: optional `aad_admin_object_id`.
- **terraform-databricks-workspace-dev.yml:** Layer 2a – Azure Databricks workspace (RM) + SP Contributor. Step 5.
- **terraform-databricks-dev.yml:** Layer 2b – dev cluster, main pipeline job (compute). Step 6.
- **deploy-notebooks.yml:** Sync notebooks to Databricks (e.g. via Repos).
- **deploy-jobs.yml:** Deploy/update Databricks jobs from repo.
- **promote-environment.yml:** Promote to prod or stg (workflow offers both; config + optional Terraform).
- **tests.yml:** Pytest unit tests + Ruff lint.
- **provision_olist_postgres.yml:** Olist Postgres + runner. **After Terraform Platform (Dev)**. Apply **Bootstrap VM** before register/bootstrap if using that VM. **action:** `plan` \| `apply` \| `destroy` \| **`full`** \| **`register_only`** \| **`bootstrap_only`**.
- **provision_postgres_ingest_function.yml:** Postgres → ADLS RAW function. **After Platform, Data Lake, Postgres (apply).** **action:** `plan` \| `apply` \| `destroy`.
- **run_postgres_raw_initial_load.yml:** Sets `INGESTION_MODE=initial`, restarts the app, **GET** probes then **POST**s `https://<app>.azurewebsites.net/api/postgres_ingest_run` with the **host master key**.
- **run_postgres_raw_incremental.yml:** Same for **`INGESTION_MODE=incremental`** (ad-hoc incremental runs).

Workflows live in [.github/workflows/](.github/workflows/).

- **Secrets:** Terraform Azure (OIDC): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (passed as `ARM_*`). **Terraform Databricks Workspace (Dev)** and **Terraform Databricks (Dev):** same OIDC app + **`AZURE_PRINCIPAL_ID`** (service principal Object ID for workspace Contributor assignment in the workspace stack); **no** `ARM_CLIENT_SECRET`. See [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md). Optional (deploy-notebooks/jobs): `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. Promote: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`. **Olist:** **`GH_PAT`** for `full` and `register_only`. **`POSTGRES_*`** optional for `bootstrap_only` (used only if Terraform state has no outputs).

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

See [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) for implementation checklist. **First:** **Provision Terraform State Backend (Dev)** → **Terraform Platform (Dev)** `apply` → **Terraform Data Lake (Dev)** `apply` → optionally **Terraform Bootstrap VM (Dev)** → **Terraform Databricks Workspace (Dev)** `apply` → **Terraform Databricks (Dev)** `apply`.

---

## Troubleshooting

- **ContainerNotFound** when running Terraform workflows: create the **tfstate** container on **retailflowdevtfstate** if missing, then re-run. See [terraform/backend/README.md](terraform/backend/README.md#troubleshooting).
- **AuthorizationFailed** on `roleAssignments/write` when running **Terraform Databricks Workspace (Dev)** or **Terraform Bastion (Dev)** (`bootstrap_vm_admin_login`): The GitHub Actions service principal needs **User Access Administrator** (or Owner) on the subscription or resource group to create role assignments. Grant that role in Azure Portal (Subscription or **retailflow-dev-rg** → Access control (IAM) → Add role assignment). For Databricks workspace Contributor assignment, see [docs/DATABRICKS_AZURE_AUTH.md](docs/DATABRICKS_AZURE_AUTH.md). For Bastion: if you cannot grant that permission, leave `aad_admin_object_id` / `AAD_ADMIN_OBJECT_ID` empty and assign **Virtual Machine Administrator Login** (or User Login) to your user on the bootstrap VM manually in Portal → VM → Access control (IAM); Bastion + Entra SSH can still work. See [docs/BASTION.md](docs/BASTION.md).
- **Postgres ingest Function — `401 Unauthorized` / “ElasticPremium VMs” / “additional quota” on apply:** The Function App uses **Elastic Premium EP1** for VNet integration. A limit of **0** in your region means you must **request a quota increase** via **Help + support** (quota ticket) or the portal Quotas UI if it lists the limit. The message is **quota**, not GitHub OIDC. Details: [terraform/postgres_ingest_function/README.md — Troubleshooting](terraform/postgres_ingest_function/README.md#troubleshooting).
- **Olist: "Load dataset into Postgres" stuck on "Waiting for a runner to pick up this job":** The bootstrap job runs on a **self-hosted** runner (the bootstrap VM). You must run **register_only** first so the runner is installed and registered. After **register_only** completes, in GitHub go to **Settings → Actions → Runners** and wait until a runner with labels `self-hosted`, `linux` shows status **Idle**. Then run **bootstrap_only**. If it still waits: confirm the bootstrap VM is running in Azure (resource group and VM name match the workflow inputs, default `retailflow-dev-rg` / `retailflow-dev-bootstrap-vm`), and that the **Install runner on VM** step in the register_only run succeeded (the workflow now fails that step if Azure run-command fails).
- **Postgres ingest — deploy step `Read timed out` to `*.scm.azurewebsites.net`:** The **Provision Postgres Ingest Function** workflow uses **`az webapp deploy`** (configurable timeout + retries) instead of **`config-zip`**, which often fails when Kudu/SCM responds slowly. If deploy still fails, retry the workflow; check **Networking** on the Function App if SCM is unreachable from GitHub-hosted runners.
- **Postgres RAW load workflow — `Request Timeout` from Azure CLI or slow invoke:** **`az functionapp keys list`** can time out on ARM; the workflows retry and set **`AZURE_CORE_HTTP_TIMEOUT`**. Very large **initial** loads need the deployed **`host.json` `functionTimeout`** (included in the function zip). Confirm **Application Insights** if the HTTP call returns 5xx while the function is still running.
- **ADLS — `az storage blob list` permission error or size sum `0`:** Listing blobs with **`--auth-mode login`** needs a **data-plane** role on the storage account (e.g. **Storage Blob Data Reader**). **Owner** on the RG alone is not enough. Alternatively use **`--auth-mode key`** with the account key if your policy allows.

---

## License

Internal / portfolio use. Adjust org names, endpoints, and secrets for your environment.
