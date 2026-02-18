variable "environment" {
  description = "Environment: dev, stg, prod"
  type        = string
}

variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "databricks_sku" {
  description = "Databricks workspace SKU"
  type        = string
  default     = "premium"
}

variable "create_networking" {
  description = "Create VNet and subnets for Databricks"
  type        = bool
  default     = false
}
