# Databricks workspace (Azure) — dev only

Creates **only** the **Azure Databricks workspace** (`retailflow-dev-dbw`, Standard SKU, VNet-injected) and optional **Contributor** role for the GitHub Actions service principal.

**State:** `retailflow-dev-databricks-workspace.tfstate`

**CI:** [Terraform Databricks Workspace (Dev)](../../.github/workflows/terraform-databricks-workspace-dev.yml)

**Order:** Run **after** [Terraform Platform (Dev)](../../.github/workflows/terraform-platform-dev.yml), **before** [Terraform Databricks (Dev)](../../.github/workflows/terraform-databricks-dev.yml) (compute: clusters + jobs).

**Destroy:** Tearing down this stack **deletes the workspace** and all workspace content (notebooks, etc.). To save cost while **keeping** the workspace, use **Terraform Databricks (Dev)** `destroy` only (compute state), not this workflow.

See [docs/DATABRICKS_AZURE_AUTH.md](../../docs/DATABRICKS_AZURE_AUTH.md) for `AZURE_PRINCIPAL_ID`.
