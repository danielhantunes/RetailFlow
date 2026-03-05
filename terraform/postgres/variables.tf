variable "azure_region" {
  description = "Azure region for PostgreSQL Flexible Server"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group for the ephemeral PostgreSQL resources"
  type        = string
  default     = "retailflow-ingest-pg-rg"
}

variable "server_name" {
  description = "Name of the PostgreSQL Flexible Server (must be unique across Azure)"
  type        = string
  default     = "retailflow-ingest-pg"
}

variable "administrator_login" {
  description = "Administrator login for PostgreSQL"
  type        = string
  default     = "retailflowadmin"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "sku_name" {
  description = "SKU for development (small instance)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "zone" {
  description = "Availability zone (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
