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

variable "tfstate_databricks_workspace_key" {
  description = "State file key for terraform/databricks_workspace (e.g. retailflow-dev-databricks-workspace.tfstate)"
  type        = string
  default     = "retailflow-dev-databricks-workspace.tfstate"
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

variable "azure_principal_id" {
  description = "Unused in this stack (workspace role is in databricks_workspace). Kept for workflow env compatibility."
  type        = string
  default     = ""
}
