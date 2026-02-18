output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "databricks_workspace_id" {
  value = module.databricks.workspace_id
}
