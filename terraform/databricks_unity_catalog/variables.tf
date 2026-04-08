variable "tfstate_resource_group_name" {
  description = "Resource group of the Terraform state storage"
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Terraform state storage account name"
  type        = string
}

variable "tfstate_container_name" {
  description = "Terraform state container name"
  type        = string
  default     = "tfstate"
}

variable "tfstate_base_key" {
  description = "State key for terraform/base (e.g. retailflow-dev-base.tfstate)"
  type        = string
  default     = "retailflow-dev-base.tfstate"
}

variable "tfstate_adls_key" {
  description = "State key for terraform/adls (e.g. retailflow-dev-adls.tfstate)"
  type        = string
  default     = "retailflow-dev-adls.tfstate"
}

variable "tfstate_databricks_workspace_key" {
  description = "State key for terraform/databricks_workspace"
  type        = string
  default     = "retailflow-dev-databricks-workspace.tfstate"
}

variable "databricks_account_id" {
  description = "Azure Databricks account ID (Account Console). Set via TF_VAR_databricks_account_id / DATABRICKS_ACCOUNT_ID in CI."
  type        = string
  sensitive   = true
}

variable "unity_catalog_container_name" {
  description = "ADLS Gen2 filesystem name for the metastore storage root"
  type        = string
  default     = "unity"
}

variable "access_connector_name" {
  description = "Azure Databricks access connector resource name"
  type        = string
  default     = "retailflow-dev-uc-connector"
}

variable "metastore_name" {
  description = "Unity Catalog metastore name (account-level)"
  type        = string
  default     = "retailflow-dev-metastore"
}

variable "metastore_data_access_name" {
  description = "Metastore data access configuration name"
  type        = string
  default     = "retailflow-dev-uc-data-access"
}

variable "tags" {
  description = "Tags for Azure resources"
  type        = map(string)
  default     = {}
}
