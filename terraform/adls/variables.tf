variable "tfstate_resource_group_name" {
  description = "Resource group of Terraform state storage (e.g. retailflow-dev-tfstate-rg)"
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state (e.g. retailflowdevtfstate)"
  type        = string
}

variable "tfstate_container_name" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "tfstate_base_key" {
  description = "State file key for base layer (e.g. retailflow-dev-base.tfstate)"
  type        = string
  default     = "retailflow-dev-base.tfstate"
}

# Used when base remote state exists but has no outputs (e.g. state not applied yet).
# Must match terraform/base naming (name_prefix = retailflow-dev) and azure_region.
variable "base_resource_group_name" {
  description = "Fallback resource group name if remote state outputs are empty"
  type        = string
  default     = "retailflow-dev-rg"
}

variable "base_vnet_name" {
  description = "Fallback VNet name if remote state outputs are empty"
  type        = string
  default     = "retailflow-dev-vnet"
}

variable "base_location" {
  description = "Fallback Azure region if remote state outputs are empty (normalize to same region as base stack)"
  type        = string
  default     = "eastus2"
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account name"
  type        = string
  default     = "retailflowdevdls"
}

variable "data_lake_containers" {
  description = "ADLS Gen2 containers/filesystems"
  type        = list(string)
  default     = ["raw", "bronze", "silver", "gold"]
}

variable "private_endpoint_subnet_name" {
  description = "Private endpoint subnet name in the base VNet (ignored if private_endpoint_subnet_id is set)"
  type        = string
  default     = "retailflow-dev-pe"
}

variable "private_endpoint_subnet_id" {
  description = "Optional full subnet resource ID for the storage private endpoint. When set, skips subnet data lookup (useful when name/RG differs or to avoid plan-time lookup)."
  type        = string
  default     = null
  nullable    = true
}

variable "create_private_endpoint" {
  description = "Create private endpoint for blob subresource"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
