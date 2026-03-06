variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "data_lake_containers" {
  description = "ADLS Gen2 filesystem (container) names – medallion layers on retailflowdevdls"
  type        = list(string)
  default     = ["raw", "bronze", "silver", "gold"]
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

# Bootstrap VM (self-hosted runner for Olist COPY into PostgreSQL)
variable "bootstrap_vm_size" {
  description = "VM size for bootstrap runner (Standard_B2s; use B1ms/B2s if B1s unavailable in region)"
  type        = string
  default     = "Standard_B2s"
}

variable "bootstrap_vm_admin_username" {
  description = "Admin username for bootstrap VM"
  type        = string
  default     = "azureuser"
}
