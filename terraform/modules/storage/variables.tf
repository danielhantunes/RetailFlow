variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_prefix" { type = string }
variable "containers" { type = list(string) }
variable "databricks_workspace_id" { type = string }
variable "databricks_workspace_principal_id" {
  description = "Databricks workspace managed identity principal_id for storage access"
  type        = string
  default     = null
}
