variable "tfstate_resource_group_name" {
  description = "Resource group of Terraform state storage (for reading base and postgres state)"
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

variable "tfstate_postgres_key" {
  description = "State file key for Postgres layer (e.g. retailflow-ingest-pg.tfstate)"
  type        = string
  default     = "retailflow-ingest-pg.tfstate"
}

variable "function_subnet_cidr" {
  description = "CIDR for the Function App subnet (must be in base VNet address space)"
  type        = string
  default     = "10.139.6.0/24"
}

variable "raw_container_name" {
  description = "ADLS container name for RAW layer"
  type        = string
  default     = "raw"
}

variable "postgres_password" {
  description = "Optional override for Postgres password (e.g. from Key Vault in CI). If empty, uses value from Postgres Terraform state."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
