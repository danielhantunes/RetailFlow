# Layer 2b – Databricks compute (dev)

Provisions **only** Databricks **resources** (not the Azure workspace):

- **Dev cluster:** `retailflow-dev-single-node`
- **Job:** `RetailFlow_Main_Pipeline` (scheduled, job cluster with Photon)

**Workspace** (Azure RM) lives in **`terraform/databricks_workspace/`** and state **`retailflow-dev-databricks-workspace.tfstate`**. Apply that **first**.

This stack reads **`workspace_url`** and **`workspace_id`** from remote state (`terraform_remote_state`) so a **single `terraform apply`** is enough.

**State file:** `retailflow-dev-databricks-compute.tfstate`

**CI:** [Terraform Databricks (Dev)](../../.github/workflows/terraform-databricks-dev.yml) — `plan` \| `apply` \| `destroy`.

**Destroy:** Removes **job + dev cluster** only; the **Databricks workspace** and **notebooks** remain. To remove the workspace, use [Terraform Databricks Workspace (Dev)](../../.github/workflows/terraform-databricks-workspace-dev.yml) `destroy` (destructive).

**Authentication:** OIDC via `azure/login`; Databricks provider uses **azure-cli**. The SP still needs **Contributor** on the workspace (created in the workspace stack). See [docs/DATABRICKS_AZURE_AUTH.md](../../docs/DATABRICKS_AZURE_AUTH.md).

**Migration:** If you have an old combined state file, see [MIGRATION.md](MIGRATION.md).
