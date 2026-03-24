# ADLS Layer (dev)

Dedicated Terraform layer for `retailflowdevdls` so storage lifecycle can be managed independently from other base resources.

## State

- Suggested backend key: `retailflow-dev-adls.tfstate`

## Dependencies

- Reads base remote state to get:
  - resource group name
  - location
  - VNet name (for private endpoint subnet lookup)

## What it manages

- ADLS Gen2 storage account (`retailflowdevdls` by default)
- Filesystems/containers (`raw`, `bronze`, `silver`, `gold`)
- Optional blob private endpoint in base private-endpoints subnet

## Migration note (important)

If ADLS is currently managed by `terraform/base`, do **not** apply both stacks for ADLS resources at the same time. Migrate ownership first (state move/import), or remove ADLS resources from base in a controlled migration.
