variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US 2"
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
