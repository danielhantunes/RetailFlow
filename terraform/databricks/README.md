# Layer 2 – Databricks (dev)

Provisions:

- **Azure Databricks workspace:** `retailflow-dev-dbw`, standard tier, VNet-injected.
- **Dev cluster:** `retailflow-dev-single-node` (single node, Standard_D4as_v5, 30 min auto-terminate).
- **Main pipeline job:** `RetailFlow_Main_Pipeline` (job cluster 1–2 workers, Photon, LTS).

Depends on Layer 1 (platform / base) via `terraform_remote_state`. Databricks resources (cluster, job) are created on the **second** apply once the workspace URL is available (the workflow does this automatically).

**Authentication:** OIDC-only via GitHub Actions. The workflow uses `azure/login` (OIDC) and the Databricks provider uses Azure AD auth based on that session. **No `ARM_CLIENT_SECRET` is required**. See [docs/DATABRICKS_AZURE_AUTH.md](../../docs/DATABRICKS_AZURE_AUTH.md).

**State file:** `retailflow-dev-databricks.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

**CI:** **Terraform Databricks (Dev)** workflow (`terraform-databricks-dev.yml`). Run `plan` | `apply` | `destroy` via workflow_dispatch. Apply the **Platform** layer first.
