# ADLS Layer (dev)

Dedicated Terraform layer for `retailflowdevdls` so storage lifecycle can be managed independently from other base resources.

## State

- Suggested backend key: `retailflow-dev-adls.tfstate`

## Dependencies

- Reads base remote state to get:
  - resource group name
  - location
  - VNet name (for private endpoint subnet lookup)

If the base state blob exists but has **no outputs** (base stack not applied yet, or stale state), plan uses fallbacks: `base_resource_group_name`, `base_location`, and `base_vnet_name` (defaults match the dev base layer). After a successful **Terraform Base (Dev) apply**, remote outputs take precedence. If you use a non-default region or name prefix in base, set the same values via `TF_VAR_base_location`, etc.

## What it manages

- ADLS Gen2 storage account (`retailflowdevdls` by default)
- Filesystems/containers (`raw`, `bronze`, `silver`, `gold`)
- Optional blob private endpoint in base private-endpoints subnet

## Migration note (important)

If ADLS is currently managed by `terraform/base`, do **not** apply both stacks for ADLS resources at the same time. Migrate ownership first (state move/import), or remove ADLS resources from base in a controlled migration.
