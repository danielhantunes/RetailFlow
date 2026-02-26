variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "data_lake_containers" {
  description = "ADLS Gen2 filesystem (container) names"
  type        = list(string)
  default     = ["raw", "processed"]
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
