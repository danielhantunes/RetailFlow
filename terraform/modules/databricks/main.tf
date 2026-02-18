# Databricks workspace module

resource "azurerm_databricks_workspace" "workspace" {
  name                = "${var.name_prefix}-adb"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  custom_parameters {
    no_public_ip        = var.virtual_network_id != null
    virtual_network_id  = var.virtual_network_id
    public_subnet_name  = var.public_subnet_id != null ? split("/", var.public_subnet_id)[length(split("/", var.public_subnet_id)) - 1] : null
    private_subnet_name = var.private_subnet_id != null ? split("/", var.private_subnet_id)[length(split("/", var.private_subnet_id)) - 1] : null
  }

  tags = {
    Environment = var.environment
    Project     = "RetailFlow"
  }
}
