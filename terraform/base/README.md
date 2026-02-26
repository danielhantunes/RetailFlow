# Layer 1 – Base Infrastructure (dev)

Resource group, virtual network, subnets, Azure Data Lake Storage Gen2 (`retailflowdevdls`, hierarchical namespace), and private endpoint for storage.

**State file:** `retailflow-dev-base.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

Managed by GitHub Actions: **Terraform Base (Dev)** workflow (`terraform-base-dev.yml`). Run `plan` | `apply` | `destroy` via workflow_dispatch.
