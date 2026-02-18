output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "raw_filesystem_id" {
  value = try(azurerm_storage_data_lake_gen2_filesystem.containers["raw"].id, null)
}
