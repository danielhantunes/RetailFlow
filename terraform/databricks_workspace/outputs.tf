output "workspace_id" {
  description = "Azure resource ID of the Databricks workspace (for Databricks provider azure_workspace_resource_id)"
  value       = azurerm_databricks_workspace.workspace.id
}

output "workspace_databricks_control_plane_id" {
  description = "Databricks control plane workspace ID (Unity Catalog metastore assignment; not the Azure resource ID)"
  value       = azurerm_databricks_workspace.workspace.workspace_id
}

output "workspace_url" {
  description = "HTTPS URL of the workspace (for Databricks provider host)"
  value       = "https://${azurerm_databricks_workspace.workspace.workspace_url}"
}

output "workspace_name" {
  value = azurerm_databricks_workspace.workspace.name
}
