output "workspace_id" {
  value = azurerm_databricks_workspace.workspace.id
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.workspace.workspace_url}"
}

output "workspace_name" {
  value = azurerm_databricks_workspace.workspace.name
}
