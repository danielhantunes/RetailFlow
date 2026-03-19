variable "tfstate_resource_group_name" {
  description = "Resource group of Terraform state storage (for reading base state)"
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

variable "azure_bastion_subnet_cidr" {
  description = "CIDR for AzureBastionSubnet (/26 minimum). Default 10.139.7.0/26 — avoid overlap with postgres_ingest_function subnet (10.139.6.0/24)."
  type        = string
  default     = "10.139.7.0/26"
}

variable "aad_admin_object_ids" {
  description = "List of Microsoft Entra object IDs to grant Virtual Machine Administrator Login on bootstrap VM."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for Bastion resources"
  type        = map(string)
  default     = {}
}
