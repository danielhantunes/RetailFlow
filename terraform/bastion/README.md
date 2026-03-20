# Azure Bastion — optional layer

Deploy **after** [Terraform Base (Dev)](../base). Use **Terraform Bastion (Dev)** workflow: `plan` | `apply` | `destroy`.

**Why separate:** Bastion is billed hourly. **Destroy** this stack when you do not need browser SSH to the private bootstrap VM (e.g. after Olist load; ongoing ingestion uses the Azure Function). **Apply** again when you need Bastion for runner setup, debugging, or VM inspection.

**State:** `retailflow-dev-bastion.tfstate`

**Resources:** `AzureBastionSubnet` in the base VNet, Standard public IP, Bastion host (**Standard**, fixed), and optional RBAC assignment (`Virtual Machine Administrator Login`) on the bootstrap VM for provided Entra Object IDs.

## Entra ID login notes

- Base layer enables `AADSSHLoginForLinux` extension on the bootstrap VM by default (`bootstrap_vm_enable_entra_login = true`).
- In the Bastion workflow, pass `aad_admin_object_id` (your Entra Object ID) to grant **Virtual Machine Administrator Login** via Terraform. If apply fails with **403** on `roleAssignments/write`, either grant the pipeline service principal **User Access Administrator** (or Owner) on the resource group, or omit `aad_admin_object_id` and assign that VM role to your user manually in Portal (see [docs/BASTION.md](../../docs/BASTION.md)).
- Bastion is fixed to **Standard** in this layer (no SKU input).

**Migration:** If Bastion was previously in `terraform/base`, run **Terraform Base (Dev) apply** first (removes Bastion from base state), then **Terraform Bastion (Dev) apply** to recreate under this state.
