# Migrating from combined Databricks state

Older setups used a **single** state file `retailflow-dev-databricks.tfstate` for both the **workspace** and **compute** (cluster + jobs), with a **two-step apply** in CI.

The repo now uses:

| Stack | State key |
|-------|-----------|
| Workspace | `retailflow-dev-databricks-workspace.tfstate` |
| Compute | `retailflow-dev-databricks-compute.tfstate` |

**Greenfield:** Run **Terraform Databricks Workspace (Dev)** apply, then **Terraform Databricks (Dev)** apply.

**Existing combined state:** Choose one:

1. **State surgery (no workspace recreate):** In the old state, `terraform state mv` the workspace resources into the new workspace stack (or import them after defining matching resources in `terraform/databricks_workspace`). Then `terraform state mv` cluster/job into compute state, or remove workspace resources from old state after workspace stack owns them.
2. **Replace:** Destroy the old combined stack (destroys workspace + jobs — **data loss in workspace**), then apply workspace + compute in order.

If unsure, open an issue or plan the move with `terraform state list` in both old and new backends.
