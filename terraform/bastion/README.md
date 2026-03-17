# Azure Bastion (Basic) — optional layer

Deploy **after** [Terraform Base (Dev)](../base). Use **Terraform Bastion (Dev)** workflow: `plan` | `apply` | `destroy`.

**Why separate:** Bastion is billed hourly. **Destroy** this stack when you do not need browser SSH to the private bootstrap VM (e.g. after Olist load; ongoing ingestion uses the Azure Function). **Apply** again when you need Bastion for runner setup, debugging, or VM inspection.

**State:** `retailflow-dev-bastion.tfstate`

**Resources:** `AzureBastionSubnet` in the base VNet, Standard public IP, Bastion host **Basic** SKU.

**Migration:** If Bastion was previously in `terraform/base`, run **Terraform Base (Dev) apply** first (removes Bastion from base state), then **Terraform Bastion (Dev) apply** to recreate under this state.
