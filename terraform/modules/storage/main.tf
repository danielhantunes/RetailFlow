# ADLS Gen2 storage for RAW and processed data

resource "azurerm_storage_account" "sa" {
  name                     = replace("${var.name_prefix}sa", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Required for Gen2

  tags = {
    Environment = "RetailFlow"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each           = toset(var.containers)
  name               = each.value
  storage_account_id = azurerm_storage_account.sa.id
}

# Assign Storage Blob Data Contributor to Databricks workspace identity (run after workspace exists)
# principal_id from: azurerm_databricks_workspace.retailflow.storage_identity[0].principal_id
resource "azurerm_role_assignment" "databricks_storage_blob" {
  count                = var.databricks_workspace_principal_id != null ? 1 : 0
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.databricks_workspace_principal_id
}
