# Azure Bastion — optional layer

Deploy **after** [Terraform Platform (Dev)](../base) and **[Terraform Bootstrap VM (Dev)](../bootstrap_vm)** (the VM must exist for VM login RBAC). Use **Terraform Bastion (Dev)** workflow: `plan` | `apply` | `destroy`.

**Why separate:** Bastion is billed hourly. **Destroy** when you do not need browser SSH to the private bootstrap VM. **Apply** when you need Portal SSH for Olist runner setup, debugging, or VM inspection.

**State:** `retailflow-dev-bastion.tfstate`

**Resources:** `AzureBastionSubnet` in the platform VNet, Standard public IP, Bastion host (**Standard**), and optional RBAC (`Virtual Machine Administrator Login`) on the bootstrap VM for provided Entra Object IDs.

Reads remote state: **platform** (`retailflow-dev-base.tfstate`) and **bootstrap VM** (`retailflow-dev-bootstrap-vm.tfstate`).

## Entra ID login notes

- The bootstrap VM stack enables `AADSSHLoginForLinux` when `bootstrap_vm_enable_entra_login = true`.
- In the Bastion workflow, pass `aad_admin_object_id` to grant **Virtual Machine Administrator Login**. If apply fails with **403** on `roleAssignments/write`, grant the pipeline service principal **User Access Administrator** or assign the role manually (see [docs/BASTION.md](../../docs/BASTION.md)).

**Migration:** If Bastion was previously in `terraform/base`, apply the slimmer platform stack first, then **Terraform Bastion (Dev) apply**.
