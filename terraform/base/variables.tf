variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US 2"
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
  description = "VM size for bootstrap runner (Standard_D2s_v3 for availability; B-series often restricted in some regions)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "bootstrap_vm_admin_username" {
  description = "Admin username for bootstrap VM"
  type        = string
  default     = "azureuser"
}

variable "bootstrap_vm_ssh_public_key" {
  description = "Optional SSH public key for bootstrap VM. When set, password auth is disabled and key-only login is used (store private key in Key Vault)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "bootstrap_vm_enable_entra_login" {
  description = "Enable Microsoft Entra ID (Azure AD) SSH login extension on bootstrap VM."
  type        = bool
  default     = true
}
