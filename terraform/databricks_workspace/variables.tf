variable "tfstate_resource_group_name" {
  description = "Resource group of the Terraform state storage"
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state"
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
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}

variable "azure_principal_id" {
  description = "Azure AD Service Principal Object ID for Contributor on the workspace (CI Databricks API). Set TF_VAR_azure_principal_id / AZURE_PRINCIPAL_ID."
  type        = string
  default     = ""
}
