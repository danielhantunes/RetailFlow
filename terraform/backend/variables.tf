variable "name_prefix" {
  description = "Prefix for resource names (e.g. retailflow-dev). Storage account name will have hyphens removed."
  type        = string
}

variable "azure_region" {
  description = "Azure region for the state resources (default for RetailFlow: East US 2)"
  type        = string
  default     = "East US 2"
}

variable "container_name" {
  description = "Name of the blob container for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
