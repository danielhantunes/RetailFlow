# Layer 1 – Base Infrastructure (dev)

Resource group, virtual network, subnets, Azure Data Lake Storage Gen2 (`retailflowdevdls`, hierarchical namespace), private endpoint for storage, bootstrap VM. **Azure Bastion** is **not** in this layer — use **Terraform Bastion (Dev)** (`terraform/bastion`) so you can apply Bastion only when needed (e.g. Olist runner setup) and **destroy** it when idle to avoid Bastion hourly cost; ongoing Postgres → ADLS uses the Azure Function.

**State file:** `retailflow-dev-base.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

Managed by GitHub Actions: **Terraform Base (Dev)** workflow (`terraform-base-dev.yml`). Run `plan` | `apply` | `destroy` via workflow_dispatch.
