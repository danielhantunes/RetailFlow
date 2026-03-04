output "workspace_id" {
  description = "Azure resource ID of the Databricks workspace (use for azure_workspace_resource_id / DATABRICKS_AZURE_RESOURCE_ID)"
  value       = azurerm_databricks_workspace.workspace.id
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.workspace.workspace_url}"
}

output "workspace_name" {
  value = azurerm_databricks_workspace.workspace.name
}

output "job_id" {
  description = "RetailFlow_Main_Pipeline job ID (when created)"
  value       = try(one(databricks_job.main_pipeline[*].id), null)
}

output "dev_cluster_id" {
  description = "Dev single-node cluster ID (when created)"
  value       = try(one(databricks_cluster.dev[*].id), null)
}
