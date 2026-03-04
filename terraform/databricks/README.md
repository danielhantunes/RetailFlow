# Layer 2 – Databricks (dev)

Provisions:

- **Azure Databricks workspace:** `retailflow-dev-dbw`, standard tier, VNet-injected.
- **Dev cluster:** `retailflow-dev-single-node` (single node, Standard_D4as_v5, 30 min auto-terminate).
- **Main pipeline job:** `RetailFlow_Main_Pipeline` (job cluster 1–2 workers, Photon, LTS).

Depends on Layer 1 (base) via `terraform_remote_state`. Databricks resources (cluster, job) are created on the **second** apply once the workspace URL is available (the workflow does this automatically).

**Authentication:** Databricks provider uses **Azure AD** (mesmo Service Principal do Azure). Adicione o app ao workspace e configure `ARM_CLIENT_SECRET` nos secrets; ver [docs/DATABRICKS_AZURE_AUTH.md](../../docs/DATABRICKS_AZURE_AUTH.md).

**State file:** `retailflow-dev-databricks.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

**CI:** **Terraform Databricks (Dev)** workflow (`terraform-databricks-dev.yml`). Run `plan` | `apply` | `destroy` via workflow_dispatch. Apply base layer first.
