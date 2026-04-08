output "metastore_id" {
  description = "Unity Catalog metastore ID"
  value       = databricks_metastore.this.id
}

output "access_connector_id" {
  description = "Azure Databricks access connector resource ID"
  value       = azurerm_databricks_access_connector.unity_catalog.id
}

output "unity_catalog_storage_container" {
  description = "ADLS filesystem used as metastore storage root"
  value       = azurerm_storage_data_lake_gen2_filesystem.unity_catalog.name
}
