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
