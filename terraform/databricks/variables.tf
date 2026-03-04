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

# Set from workflow: after first apply, export from Terraform outputs so job and cluster can be created.
variable "databricks_host" {
  description = "Databricks workspace URL (e.g. https://adb-xxx.azuredatabricks.net). Leave empty on first apply; set from output on second apply."
  type        = string
  default     = ""
}

variable "databricks_workspace_resource_id" {
  description = "Azure resource ID of the Databricks workspace (e.g. /subscriptions/.../resourceGroups/.../providers/Microsoft.Databricks/workspaces/retailflow-dev-dbw). Set from output on second apply when using Azure AD auth."
  type        = string
  default     = ""
}

# Object ID of the Azure AD Service Principal (Enterprise Application). When set, Terraform grants this principal Contributor on the workspace so it can use the Databricks API (no manual add to workspace). Set in CI via TF_VAR_azure_principal_id (e.g. from secret AZURE_PRINCIPAL_ID).
variable "azure_principal_id" {
  description = "Azure AD Service Principal Object ID (Enterprise Application). Used to grant Contributor on the Databricks workspace so the SP can authenticate to the Databricks API. Set in CI for apply/destroy."
  type        = string
  default     = ""
}
