output "workspace_id" {
  value = azurerm_databricks_workspace.workspace.id
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.workspace.workspace_url}"
}

output "workspace_storage_principal_id" {
  value = try(azurerm_databricks_workspace.workspace.storage_identity[0].principal_id, null)
}
