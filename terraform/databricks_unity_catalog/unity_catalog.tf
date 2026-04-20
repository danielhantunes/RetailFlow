# Dedicated filesystem for Unity Catalog managed storage root (separate from raw/bronze/silver/gold).
resource "azurerm_storage_data_lake_gen2_filesystem" "unity_catalog" {
  name               = var.unity_catalog_container_name
  storage_account_id = local.storage_account_id
}

resource "azurerm_databricks_access_connector" "unity_catalog" {
  name                = var.access_connector_name
  resource_group_name = local.rg_name
  location            = local.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "access_connector_blob_data" {
  scope                = local.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

resource "databricks_metastore" "this" {
  provider = databricks.account

  name          = var.metastore_name
  storage_root  = "abfss://${azurerm_storage_data_lake_gen2_filesystem.unity_catalog.name}@${local.storage_account_name}.dfs.core.windows.net/"
  region        = local.location
  force_destroy = true
}

resource "databricks_metastore_data_access" "this" {
  provider = databricks.account

  metastore_id = databricks_metastore.this.id
  name         = var.metastore_data_access_name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity_catalog.id
  }
  is_default = true

  depends_on = [azurerm_role_assignment.access_connector_blob_data]
}

resource "databricks_metastore_assignment" "this" {
  provider = databricks.account
  count    = local.databricks_workspace_control_plane_id != null ? 1 : 0

  workspace_id = local.databricks_workspace_control_plane_id
  metastore_id = databricks_metastore.this.id

  depends_on = [databricks_metastore_data_access.this]
}
