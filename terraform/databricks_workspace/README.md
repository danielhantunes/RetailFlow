# Databricks workspace (Azure) — dev only

Creates **only** the **Azure Databricks workspace** (`retailflow-dev-dbw`, Premium SKU, VNet-injected) and optional **Contributor** role for the GitHub Actions service principal.

**State:** `retailflow-dev-databricks-workspace.tfstate`

**CI:** [Terraform Databricks Workspace (Dev)](../../.github/workflows/terraform-databricks-workspace-dev.yml)

**Unity Catalog (always):** [terraform/databricks_unity_catalog](../databricks_unity_catalog/) — metastore + workspace assignment runs on every [Terraform Databricks Workspace (Dev)](../../.github/workflows/terraform-databricks-workspace-dev.yml) plan/apply/destroy. Set GitHub secret **`DATABRICKS_ACCOUNT_ID`**. Requires **Terraform Data Lake (Dev)** applied first. **Destroy** runs UC **before** workspace in that workflow.

**Order:** Run **after** [Terraform Platform (Dev)](../../.github/workflows/terraform-platform-dev.yml) and **Terraform Data Lake (Dev)** (for UC), **before** [Terraform Databricks (Dev)](../../.github/workflows/terraform-databricks-dev.yml) (compute: clusters + jobs).

**Destroy:** Tearing down this stack **deletes the workspace** and all workspace content (notebooks, etc.). To save cost while **keeping** the workspace, use **Terraform Databricks (Dev)** `destroy` only (compute state), not this workflow.

See [docs/DATABRICKS_AZURE_AUTH.md](../../docs/DATABRICKS_AZURE_AUTH.md) for `AZURE_PRINCIPAL_ID`.
