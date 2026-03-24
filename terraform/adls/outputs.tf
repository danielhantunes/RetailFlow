output "storage_account_name" {
  value       = azurerm_storage_account.dls.name
  description = "ADLS Gen2 storage account name"
}

output "storage_account_id" {
  value       = azurerm_storage_account.dls.id
  description = "ADLS Gen2 storage account resource ID"
}

output "container_names" {
  value       = [for c in azurerm_storage_data_lake_gen2_filesystem.containers : c.name]
  description = "ADLS filesystem names"
}
