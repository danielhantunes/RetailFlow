resource "azurerm_key_vault" "kv" {
  name                        = replace("${var.name_prefix}-kv", "-", "")
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  tags = {
    Environment = "RetailFlow"
  }
}

# Grant Databricks workspace access to get secrets (use workspace identity or service principal)
# Example: use Azure AD app or workspace MSI
# resource "azurerm_key_vault_access_policy" "databricks" { ... }
