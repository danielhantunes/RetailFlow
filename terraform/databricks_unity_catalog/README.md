# Unity Catalog metastore (Azure Databricks) — dev

Creates a **Unity Catalog metastore** and **assigns** it to the dev workspace:

- ADLS Gen2 filesystem for metastore `storage_root` (default: `unity` on `retailflowdevdls`)
- **Azure Databricks access connector** + **Storage Blob Data Contributor** on the data lake storage account
- `databricks_metastore`, `databricks_metastore_data_access`, `databricks_metastore_assignment`

**State:** `retailflow-dev-databricks-unity-catalog.tfstate`

**CI:** Not executed by the workspace workflow anymore. Run this stack separately only if you want Terraform-managed UC resources.

## Prerequisites

1. **Terraform Platform (Dev)** — base state
2. **Terraform Data Lake (Dev)** — ADLS state (`retailflow-dev-adls.tfstate`)
3. **Terraform Databricks Workspace (Dev)** — workspace state
4. **Azure AD identity** used in CI (OIDC app) is **Databricks account admin** (Account Console → User management) so account-level metastore APIs succeed
5. GitHub secret **`DATABRICKS_ACCOUNT_ID`**: Azure Databricks account ID (Account Console URL / account settings)

## Order

- **Apply:** after workspace.
- **Destroy:** run **Unity Catalog destroy** before destroying the workspace stack when UC was created by this Terraform state.

## Local apply

```bash
cd terraform/databricks_unity_catalog
export TF_VAR_databricks_account_id="<account-guid>"
terraform init \
  -backend-config="resource_group_name=..." \
  -backend-config="storage_account_name=..." \
  -backend-config="container_name=tfstate" \
  -backend-config="key=retailflow-dev-databricks-unity-catalog.tfstate"
terraform plan
```

After metastore assignment, create catalogs in SQL (see [docs/UNITY_CATALOG.md](../../docs/UNITY_CATALOG.md)).
