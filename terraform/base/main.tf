# Layer 1 – Base Infrastructure ONLY (dev)
# This root contains ONLY base infrastructure: Resource Group, VNet, Subnets, ADLS Gen2 (retailflowdevdls), Private Endpoint.
# No Databricks or other compute. State: retailflow-dev-base.tfstate

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    # In CI: pass -backend-config or set via env (resource_group_name, storage_account_name, container_name, key=retailflow-dev-base.tfstate)
  }
}

provider "azurerm" {
  features {}
}

locals {
  name_prefix = "retailflow-dev"
  location     = var.azure_region
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = local.location
  tags     = var.tags
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  address_space       = ["10.139.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Subnets (including dedicated subnet for private endpoints)
resource "azurerm_subnet" "public" {
  name                 = "${local.name_prefix}-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "${local.name_prefix}-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.2.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${local.name_prefix}-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.3.0/24"]
}

# Azure Data Lake Storage Gen2 (name: retailflowdevdls, hierarchical namespace)
resource "azurerm_storage_account" "dls" {
  name                     = "retailflowdevdls"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each           = toset(var.data_lake_containers)
  name               = each.value
  storage_account_id = azurerm_storage_account.dls.id
}

# Private endpoint for storage (blob)
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.name_prefix}-dls-blob-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${local.name_prefix}-dls-blob-psc"
    private_connection_resource_id = azurerm_storage_account.dls.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = var.tags
}
