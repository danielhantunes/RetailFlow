# Bootstrap VM (dev, on-demand)

Self-hosted runner / toolbox VM for Olist CSV → PostgreSQL and ad-hoc `psql`. **Not** used for scheduled ingestion (that is the Azure Function).

## State

- Backend key: `retailflow-dev-bootstrap-vm.tfstate`

## Dependencies

- **Terraform Platform (Dev)** (`terraform/base`) applied: VNet and resource group must exist.

## Workflow

GitHub Actions: **Terraform Bootstrap VM (Dev)** (`terraform-bootstrap-vm-dev.yml`) — `plan` | `apply` | `destroy`.

**Apply** when you need the VM; **destroy** when idle to save cost.

## Migration from older layouts

If the VM was previously managed in `terraform/base`, remove those resources from base state and import/move into this stack, or destroy the VM via the old stack once, then apply this stack. See Terraform `state mv` / `state rm` documentation.

## Related

- **Azure Bastion** (`terraform/bastion`) — optional; reads `bootstrap_vm_id` from this state.
- **TOOLBOX.md** — usage on the VM.
