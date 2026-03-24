# ADLS Layer (dev)

Dedicated Terraform layer for `retailflowdevdls` so storage lifecycle can be managed independently from other base resources.

## State

- Suggested backend key: `retailflow-dev-adls.tfstate`

## Dependencies

- Reads base remote state to get:
  - resource group name
  - location
  - VNet name (for private endpoint subnet lookup)

If the platform (`terraform/base`) state blob has **no outputs**, plan uses fallbacks. After a successful **Terraform Platform (Dev) apply**, remote outputs take precedence. Override with `TF_VAR_base_*` if needed.

### Subnet not found (`retailflow-dev-pe`)

The private endpoint needs the **private endpoints subnet** created by `terraform/base` (`retailflow-dev-pe`). If plan errors with subnet not found:

1. Run **`Terraform Platform (Dev)` → apply** so the VNet and PE subnet exist; state should include `private_endpoints_subnet_id`.
2. Or set **`create_private_endpoint = false`** (e.g. `TF_VAR_create_private_endpoint=false`) to provision the storage account and filesystems only; add the PE later.

Optional: set **`private_endpoint_subnet_id`** to the full subnet resource ID if your layout uses a different name or RG.

## What it manages

- ADLS Gen2 storage account (`retailflowdevdls` by default)
- Filesystems/containers (`raw`, `bronze`, `silver`, `gold`)
- Optional blob private endpoint in base private-endpoints subnet

## Migration note (important)

If ADLS is currently managed by `terraform/base`, do **not** apply both stacks for ADLS resources at the same time. Migrate ownership first (state move/import), or remove ADLS resources from base in a controlled migration.
