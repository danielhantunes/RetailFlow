output "function_app_name" {
  value       = azurerm_linux_function_app.main.name
  description = "Name of the Linux Function App (for zip deploy)"
}

output "function_app_resource_group" {
  value       = azurerm_linux_function_app.main.resource_group_name
  description = "Resource group of the Function App"
}

output "function_app_id" {
  value       = azurerm_linux_function_app.main.id
  description = "Resource ID of the Function App"
}
