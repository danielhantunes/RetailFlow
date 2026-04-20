# Databricks workspace only (Azure RM). Long-lived; destroy compute separately via terraform/databricks.
# State: retailflow-dev-databricks-workspace.tfstate
# Depends on: terraform/base (Platform). Run before terraform/databricks (compute).

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    # CI: -backend-config key=retailflow-dev-databricks-workspace.tfstate
  }
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "base" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_base_key
  }
}

locals {
  rg_name         = data.terraform_remote_state.base.outputs.resource_group_name
  location        = data.terraform_remote_state.base.outputs.location
  vnet_id         = data.terraform_remote_state.base.outputs.vnet_id
  public_subnet_id  = data.terraform_remote_state.base.outputs.public_subnet_id
  private_subnet_id = data.terraform_remote_state.base.outputs.private_subnet_id
}

resource "azurerm_databricks_workspace" "workspace" {
  name                = "retailflow-dev-dbw"
  resource_group_name = local.rg_name
  location            = local.location
  sku                 = "premium"

  custom_parameters {
    no_public_ip        = true
    virtual_network_id  = local.vnet_id
    public_subnet_name  = split("/", local.public_subnet_id)[length(split("/", local.public_subnet_id)) - 1]
    private_subnet_name = split("/", local.private_subnet_id)[length(split("/", local.private_subnet_id)) - 1]
    public_subnet_network_security_group_association_id  = data.terraform_remote_state.base.outputs.public_subnet_network_security_group_association_id
    private_subnet_network_security_group_association_id = data.terraform_remote_state.base.outputs.private_subnet_network_security_group_association_id
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "databricks_workspace_contributor" {
  count                = var.azure_principal_id != "" ? 1 : 0
  scope                = azurerm_databricks_workspace.workspace.id
  role_definition_name = "Contributor"
  principal_id         = var.azure_principal_id
}
