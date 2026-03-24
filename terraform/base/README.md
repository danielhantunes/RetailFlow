# Layer 1 – Platform (dev)

Resource group, virtual network, subnets (including two subnets delegated for **future** Azure Databricks VNet injection — these are plain Azure Network resources, not a Databricks workspace), private-endpoint and Postgres subnets, NSGs, and Postgres private DNS zone + VNet link.

**Not in this layer:** Any **Databricks product** resources (workspace, etc.) — use **`terraform/databricks`** and **Terraform Databricks (Dev)**. Also excluded: ADLS (`terraform/adls`), bootstrap VM (`terraform/bootstrap_vm`), Azure Bastion (`terraform/bastion`).

**State file:** `retailflow-dev-base.tfstate` (in `retailflow-dev-tfstate-rg` / `retailflowdevtfstate`).

Managed by GitHub Actions: **[Terraform Platform (Dev)](../../.github/workflows/terraform-platform-dev.yml)** — `plan` \| `apply` \| `destroy`.

## Migration from older `terraform/base`

If your state still tracks ADLS or the bootstrap VM, remove those resources from state (`terraform state rm …`) or destroy them in Azure, then apply this slimmer module. Move ADLS to `terraform/adls` and the VM to `terraform/bootstrap_vm` per their READMEs.
