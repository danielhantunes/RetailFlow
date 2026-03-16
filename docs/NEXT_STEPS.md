# RetailFlow — Next Steps to Implement

## 1. Terraform

- **State backend (OIDC + GitHub Actions):** Provision the Terraform remote state first. In GitHub, configure OIDC (federated credential in Azure AD + secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`). Run **Provision Terraform State Backend (Dev)** to create the dev backend (`retailflowdevtfstate`); run **Provision Terraform State Backend (Prod)** to create the prod backend (`retailflowprodtfstate`). Then run **Terraform Base (Dev)** (plan → apply), then **Terraform Databricks (Dev)** (plan → apply). See [README — CI/CD](../README.md#cicd-github-actions) for order. Configure the main root’s backend from the workflow output (`terraform output backend_config`) or see [terraform/backend/README.md](../terraform/backend/README.md). Default region is **East US 2**. For backend or Databricks apply failures, see [README — Troubleshooting](../README.md#troubleshooting).
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set `environment`, `azure_region` (default: East US 2), and optionally `create_networking`.
- Run `terraform init` with backend config (from provision workflow output), then `terraform plan`, `terraform apply` for dev. For prod, use prod backend config and prod tfvars (separate state in `retailflowprodtfstate`).
- Note: Storage module expects `databricks_workspace_principal_id` for role assignment; if the workspace does not expose `storage_identity`, assign Storage Blob Data Contributor to the workspace identity manually in Azure Portal.

## 2. Unity Catalog and secret scope

- In Databricks, create catalog and schemas (e.g. `retailflow_dev.raw`, `.bronze`, `.silver`, `.gold`) or use Terraform `databricks_catalog` / `databricks_schema` if available.
- Create a secret scope backed by Azure Key Vault (Databricks UI or script in `scripts/deploy_secret_scope.py`). Grant the Databricks workspace MSI Get/List on the Key Vault.
- Add secrets: `orders-api-key`, `customers-api-key`, and any SQL DB connection strings.

## 3. RAW layer bootstrap

- Create RAW folder structure on ADLS (e.g. `data/raw/orders`, `customers`, `products`, `inventory`, `clickstream`, `payments`, `store_sales`). Use Azure Portal, Azure CLI, or `scripts/bootstrap_raw_folders.sh` as reference.

## 4. Config and cluster settings

- Set Spark config and cluster environment variables (or job parameters) from `config/environments/<env>.yaml`: e.g. `retailflow.catalog`, `retailflow.raw_path`, `retailflow.orders_api_url`, etc.
- Enable AQE and Delta auto-optimize on job clusters (already in job JSON).

## 5. Run ingestion and pipelines

- **Target flow:** PostgreSQL → **Azure Function** (timer) → ADLS RAW → Databricks Bronze/Silver → Snowflake Gold → dbt → analytics marts. See [DATA_FLOW.md](DATA_FLOW.md) and [README — Target data flow](../README.md#target-data-flow).
- **Postgres → RAW (scheduled):** Run **Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`) after Terraform Base (Dev) and Postgres (apply). The workflow provisions the Azure Function App (VNet integration, managed identity, role on ADLS) and deploys the code from `functions/postgres_to_raw`. The function runs on a timer and reads from Postgres, writes to ADLS RAW. **VM toolbox** is for one-time/ad-hoc loads and Postgres inspection only; see [TOOLBOX.md](TOOLBOX.md). Initial Olist load is done by the Provision PostgreSQL for Olist workflow (CSV COPY on the VM).
- Run RAW ingestion notebooks (orders, customers, products, etc.) for other sources; validate files under RAW paths.
- Run Bronze notebooks/DLT to populate Bronze tables; then Silver, then Gold.
- Run the main pipeline job (provisioned by Terraform in `terraform/databricks/databricks_resources.tf`; adjust notebook paths in Terraform if needed, e.g. Repos path).

## 6. Delta Live Tables

- Create a DLT pipeline in Databricks pointing to `dlt/pipelines/bronze_silver_dlt.py`; set pipeline config (raw path, catalog, storage for schema location). Run in development then production mode.

## 7. Optional: Airflow

- Install `apache-airflow-providers-databricks`; configure connection `databricks_default`. Deploy `airflow/dags/retailflow_medallion_dag.py` and set the Databricks `job_id` in the DAG.

## 8. Optional: dbt

- Set env vars: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, and optionally `DATABRICKS_CLUSTER_ID`. Run `dbt run` and `dbt test` from `dbt/retailflow/` for marts.

## 9. CI/CD

- In GitHub, add secrets: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. For **Terraform state backend (OIDC):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (no client secret). For **Terraform Databricks (Dev):** also `ARM_CLIENT_SECRET` and `AZURE_PRINCIPAL_ID` (service principal Object ID); the SP needs **User Access Administrator** or Owner on the subscription or resource group to create the workspace role assignment—see [DATABRICKS_AZURE_AUTH.md](DATABRICKS_AZURE_AUTH.md). **Postgres Ingest Function** uses the same OIDC secrets as other Terraform workflows (no extra secrets). For environment promotion: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`; optionally use GitHub Environments (stg, prod).
- **Optional Olist PostgreSQL:** Run **Provision PostgreSQL for Olist** (`provision_olist_postgres.yml`) **after Terraform Base (Dev)** only (Postgres Terraform reads base state for delegated subnet and private DNS; it does not depend on Databricks). If Databricks will ingest from PostgreSQL (Olist), use order: Base → Postgres (apply + bootstrap) → Databricks so the database is ready before ingestion. Add secret **`GH_PAT`** (GitHub PAT with Actions or repo admin) for runner registration when using `action: full` or `register_only`. Sequence: plan → apply → **register_only** → wait until the self-hosted runner shows **Idle** in **Settings → Actions → Runners** → **bootstrap_only** → destroy. The workflow installs the data-engineering toolbox on the runner VM when running **full** or **bootstrap_only**; see [TOOLBOX.md](TOOLBOX.md) for using it (psql, Python, Key Vault). If "Load dataset into Postgres" stays on "Waiting for a runner", see [README — Troubleshooting](../README.md#troubleshooting). See [README — CI/CD](../README.md#cicd-github-actions).
- Adjust deploy workflows to your repo structure (e.g. Repos repo ID for notebook sync).

## 10. Observability

- Configure job failure notifications in Databricks. Optionally persist run metadata to Delta or Azure Monitor using `databricks/notebooks/observability/job_monitor.py`.
- Add Azure Monitor alerts on storage or Databricks metrics if required.

After these steps, the platform is ready for production use and iteration (e.g. more entities, incremental logic, and data quality rules).
