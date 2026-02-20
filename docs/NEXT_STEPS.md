# RetailFlow — Next Steps to Implement

## 1. Terraform

- **State backend (OIDC + GitHub Actions):** Provision the Terraform remote state first. In GitHub, configure OIDC (federated credential in Azure AD + secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`). Run the **Provision Terraform State Backend** workflow once, then fill `backend "azurerm"` in `terraform/main.tf` from the workflow output (or from `terraform output backend_config` if you ran `terraform/backend` locally).
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set `environment`, `azure_region`, and optionally `create_networking`.
- Run `terraform init`, `terraform plan`, `terraform apply` for dev. Repeat for stg/prod using separate tfvars or workspaces.
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

- Run RAW ingestion notebooks (orders, customers, products, etc.) with correct widget values or config. Validate files under RAW paths.
- Run Bronze notebooks/DLT to populate Bronze tables; then Silver, then Gold.
- Deploy and run the main job from `databricks/jobs/retailflow_main_job.json` (adjust notebook paths to your workspace, e.g. Repos path).

## 6. Delta Live Tables

- Create a DLT pipeline in Databricks pointing to `dlt/pipelines/bronze_silver_dlt.py`; set pipeline config (raw path, catalog, storage for schema location). Run in development then production mode.

## 7. Optional: Airflow

- Install `apache-airflow-providers-databricks`; configure connection `databricks_default`. Deploy `airflow/dags/retailflow_medallion_dag.py` and set the Databricks `job_id` in the DAG.

## 8. Optional: dbt

- Set env vars: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, and optionally `DATABRICKS_CLUSTER_ID`. Run `dbt run` and `dbt test` from `dbt/retailflow/` for marts.

## 9. CI/CD

- In GitHub, add secrets: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`. For **Terraform state backend (OIDC):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (no client secret). For environment promotion: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`; optionally use GitHub Environments (stg, prod).
- Adjust deploy workflows to your repo structure (e.g. Repos repo ID for notebook sync).

## 10. Observability

- Configure job failure notifications in Databricks. Optionally persist run metadata to Delta or Azure Monitor using `databricks/notebooks/observability/job_monitor.py`.
- Add Azure Monitor alerts on storage or Databricks metrics if required.

After these steps, the platform is ready for production use and iteration (e.g. more entities, incremental logic, and data quality rules).
