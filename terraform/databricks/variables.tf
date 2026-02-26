variable "tfstate_resource_group_name" {
  description = "Resource group of the Terraform state storage (e.g. retailflow-dev-tfstate-rg)"
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

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
