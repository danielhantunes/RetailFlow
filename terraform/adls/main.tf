terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {}
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
  # Base state sometimes has no outputs (never applied, or empty state blob). try() avoids plan failure;
  # fallbacks match terraform/base defaults (name_prefix retailflow-dev, region eastus2).
  _out      = data.terraform_remote_state.base.outputs
  rg_name   = coalesce(try(local._out.resource_group_name, null), var.base_resource_group_name)
  location  = coalesce(try(local._out.location, null), var.base_location)
  vnet_name = coalesce(try(local._out.vnet_name, null), var.base_vnet_name)
  pe_name   = "retailflow-dev-dls-blob-pe"
}

data "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = local.vnet_name
  resource_group_name  = local.rg_name
}

resource "azurerm_storage_account" "dls" {
  name                     = var.storage_account_name
  resource_group_name      = local.rg_name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags                     = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each           = toset(var.data_lake_containers)
  name               = each.value
  storage_account_id = azurerm_storage_account.dls.id
}

resource "azurerm_private_endpoint" "storage_blob" {
  count               = var.create_private_endpoint ? 1 : 0
  name                = local.pe_name
  location            = local.location
  resource_group_name = local.rg_name
  subnet_id           = data.azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${local.pe_name}-psc"
    private_connection_resource_id = azurerm_storage_account.dls.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = var.tags
}
