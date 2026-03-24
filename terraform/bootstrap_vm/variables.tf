variable "tfstate_resource_group_name" {
  description = "Resource group containing Terraform remote state storage"
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state"
  type        = string
}

variable "tfstate_container_name" {
  description = "Blob container for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "tfstate_base_key" {
  description = "State key for platform/base layer (e.g. retailflow-dev-base.tfstate)"
  type        = string
  default     = "retailflow-dev-base.tfstate"
}

variable "bootstrap_vm_size" {
  description = "VM size (Standard_D2s_v3 recommended)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "bootstrap_vm_admin_username" {
  type    = string
  default = "azureuser"
}

variable "bootstrap_vm_ssh_public_key" {
  description = "Optional SSH public key; when set, password auth is disabled"
  type        = string
  default     = ""
  sensitive   = true
}

variable "bootstrap_vm_enable_entra_login" {
  description = "Microsoft Entra ID SSH login extension"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
