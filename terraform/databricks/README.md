# Layer 2 – Compute (dev)

Azure Databricks workspace: **retailflow-dev-dbw**, **standard** tier. Depends on Layer 1 (base) via `terraform_remote_state`.

**State file:** `retailflow-dev-databricks.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

Managed by GitHub Actions: **Terraform Databricks (Dev)** workflow (`terraform-databricks-dev.yml`). Run `plan` | `apply` | `destroy` via workflow_dispatch. Apply base layer first.
