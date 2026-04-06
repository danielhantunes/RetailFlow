# RetailFlow — Next Steps to Implement

## 1. Terraform

- **State backend (OIDC + GitHub Actions):** Provision the Terraform remote state first. In GitHub, configure OIDC (federated credential in Azure AD + secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`). Run **Provision Terraform State Backend (Dev)** to create the dev backend (`retailflowdevtfstate`); run **Provision Terraform State Backend (Prod)** to create the prod backend (`retailflowprodtfstate`). Then run **Terraform Platform (Dev)** (plan → apply), **Terraform Data Lake (Dev)** (ADLS), optionally **Terraform Bootstrap VM (Dev)**, then **Terraform Databricks Workspace (Dev)** (plan → apply), then **Terraform Databricks (Dev)** (plan → apply). See [README — CI/CD](../README.md#cicd-github-actions). Configure the main root’s backend from the workflow output (`terraform output backend_config`) or see [terraform/backend/README.md](../terraform/backend/README.md). Default region is **East US 2**. For backend or Databricks apply failures, see [README — Troubleshooting](../README.md#troubleshooting).
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set `environment`, `azure_region` (default: East US 2), and optionally `create_networking`.
- Run `terraform init` with backend config (from provision workflow output), then `terraform plan`, `terraform apply` for dev. For prod, use prod backend config and prod tfvars (separate state in `retailflowprodtfstate`).
- **ADLS** is managed by **Terraform Data Lake (Dev)** (`terraform-data-lake-dev.yml`) + `terraform/adls` (separate state from platform). If upgrading from an older repo where ADLS lived in `terraform/base`, migrate state before applying.
- Note: Storage module expects `databricks_workspace_principal_id` for role assignment; if the workspace does not expose `storage_identity`, assign Storage Blob Data Contributor to the workspace identity manually in Azure Portal.

## 2. Unity Catalog and secret scope

- In Databricks, create catalog and schemas (e.g. `retailflow_dev.raw`, `.bronze`, `.silver`, `.gold`) or use Terraform `databricks_catalog` / `databricks_schema` if available.
- Create a secret scope backed by Azure Key Vault (Databricks UI or script in `scripts/deploy_secret_scope.py`). Grant the Databricks workspace MSI Get/List on the Key Vault.
- Add secrets: `orders-api-key`, `customers-api-key`, and any SQL DB connection strings.

## 3. RAW layer bootstrap

- **Source (current):** **PostgreSQL** → **Postgres → RAW function** writes under **`postgres_ingest/{table}/...`** on the **Data Lake** storage account (from **`terraform/adls`**, default **`retailflowdevdls`**). No manual folders required; data appears after successful runs (check **`postgres_ingest/_runs`** for manifests). **Optional:** sample **REST/CSV** notebooks may use other prefixes (e.g. `data/raw/orders`); create those layouts as needed, or use Azure Portal, Azure CLI, and `scripts/bootstrap_raw_folders.sh` as reference.
- **`config/environments/dev.yaml`:** Defaults `storage.account_name` / `base_path` to **`retailflowdevdls`** (dev ADLS from **Terraform Data Lake**). Change values if your deployment uses another account name or region-specific naming.

## 4. Config and cluster settings

- Set Spark config and cluster environment variables (or job parameters) from `config/environments/<env>.yaml`: e.g. `retailflow.catalog`, `retailflow.raw_path`, `retailflow.orders_api_url`, etc.
- Enable AQE and Delta auto-optimize on job clusters (already in job JSON).

## 5. Run ingestion and pipelines

- **Target flow:** PostgreSQL → **Azure Function** (timer; manual via **`POST /api/postgres_ingest_run`**) → ADLS RAW (`postgres_ingest/...`) → Databricks Bronze/Silver → Snowflake Gold → dbt → analytics marts. See [DATA_FLOW.md](DATA_FLOW.md) and [README — Target data flow](../README.md#target-data-flow).
- **Azure Bastion (on-demand):** Run **Terraform Bastion (Dev)** after Platform + **Bootstrap VM** when you need browser SSH; **destroy** when idle.
- **Postgres → RAW (scheduled):** Run **Provision Postgres Ingest Function** after **Terraform Platform (Dev)**, **Terraform Data Lake (Dev)**, and Postgres (apply). The workflow provisions the Function App (VNet integration, managed identity, role on ADLS) and deploys from `functions/postgres_to_raw` (zip via **`az webapp deploy`**). The function runs on a timer and writes **JSONL** under **`postgres_ingest/`** on the RAW filesystem. **VM toolbox** is for one-time/ad-hoc loads and Postgres inspection only; see [TOOLBOX.md](TOOLBOX.md). Initial Olist load is done by the Provision PostgreSQL for Olist workflow (CSV COPY on the VM). If apply fails with **Elastic Premium** / **quota** / misleading **401**, or deploy/SCM timeouts, see [terraform/postgres_ingest_function/README.md](../terraform/postgres_ingest_function/README.md) (Troubleshooting).
- **Function runtime execution:** Recurring runs use **`POSTGRES_TIMER_SCHEDULE`** (default every 15 minutes). **Ad-hoc:** **Run Postgres RAW Initial Load** / **Incremental** set `INGESTION_MODE` and call **`/api/postgres_ingest_run`** with the host key (see module README).
- **Resilience / restart behavior:** Postgres ingestion is chunked and checkpointed to ADLS (`_control/postgres_watermarks/<table>.json`). If a run is interrupted, rerunning continues from the last committed chunk cursor (`last_watermark` + `last_pk`). Run manifests are written under `postgres_ingest/_runs/...`.
- **Mandatory when PostgreSQL is the source of origin:** Run **Provision PostgreSQL for Olist** before the ingest function. Recommended order: **Platform → Data Lake → Postgres → Postgres Ingest Function** (apply **Bootstrap VM** before runner steps if using the VM).
- Optionally run RAW **sample** notebooks (orders, customers, products APIs/CSV) for non-Postgres demos; validate files under RAW paths. **Production** data for the default pipeline comes from **PostgreSQL → `postgres_ingest/`**.
- Run Bronze notebooks/DLT to populate Bronze tables; then Silver, then Gold.
- Run the main pipeline job (provisioned by Terraform in `terraform/databricks/databricks_resources.tf`; adjust notebook paths in Terraform if needed, e.g. Repos path).

## 6. Delta Live Tables

- Create a DLT pipeline in Databricks pointing to `dlt/pipelines/bronze_silver_dlt.py`; set pipeline config (raw path, catalog, storage for schema location). Run in development then production mode.

## 7. Optional: Airflow

- Install `apache-airflow-providers-databricks`; configure connection `databricks_default`. Deploy `airflow/dags/retailflow_medallion_dag.py` and set the Databricks `job_id` in the DAG.

## 8. Optional: dbt

- Set env vars: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, and optionally `DATABRICKS_CLUSTER_ID`. Run `dbt run` and `dbt test` from `dbt/retailflow/` for marts.

## 9. CI/CD

- In GitHub, add secrets: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. For **Terraform state backend (OIDC):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (no client secret). For **Terraform Databricks Workspace (Dev)** and **Terraform Databricks (Dev):** **`AZURE_PRINCIPAL_ID`** (service principal Object ID; used by the workspace stack for Contributor assignment); **no** `ARM_CLIENT_SECRET` — Databricks Terraform uses OIDC via `azure/login`. The SP still needs **User Access Administrator** or Owner on the subscription or resource group to create the workspace role assignment—see [DATABRICKS_AZURE_AUTH.md](DATABRICKS_AZURE_AUTH.md). **Terraform Bastion (Dev)** may create a VM **Virtual Machine Administrator Login** assignment; the same **User Access Administrator** (or Owner) permission applies, or assign that role on the VM manually and omit `aad_admin_object_id`. **Postgres Ingest Function** uses the same OIDC secrets as other Terraform workflows (no extra secrets). For environment promotion: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`; optionally use GitHub Environments (stg, prod).
- **Optional Olist PostgreSQL:** Run **Provision PostgreSQL for Olist** **after Terraform Platform (Dev)**. Order when using Postgres as source: Platform → Data Lake → Postgres → Databricks / ingest function. Apply **Bootstrap VM** before `register_only` / `bootstrap_only` if using that VM. Add secret **`GH_PAT`** (GitHub PAT with Actions or repo admin) for runner registration when using `action: full` or `register_only`. Sequence: plan → apply → **register_only** → wait until the self-hosted runner shows **Idle** in **Settings → Actions → Runners** → **bootstrap_only** → destroy. The workflow installs the data-engineering toolbox on the runner VM when running **full** or **bootstrap_only**; see [TOOLBOX.md](TOOLBOX.md) for using it (psql, Python, Bastion + Entra) and optional source checks in **Data Quality Validation (Source Layer - PostgreSQL)**. If "Load dataset into Postgres" stays on "Waiting for a runner", see [README — Troubleshooting](../README.md#troubleshooting). See [README — CI/CD](../README.md#cicd-github-actions).
- Adjust deploy workflows to your repo structure (e.g. Repos repo ID for notebook sync).

## 10. Observability

- Configure job failure notifications in Databricks. Optionally persist run metadata to Delta or Azure Monitor using `databricks/notebooks/observability/job_monitor.py`.
- Add Azure Monitor alerts on storage or Databricks metrics if required.

After these steps, the platform is ready for production use and iteration (e.g. more entities, incremental logic, and data quality rules).
