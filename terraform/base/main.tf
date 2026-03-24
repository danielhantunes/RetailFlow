# Layer 1 – Platform (dev): Resource Group, VNet, subnets, NSGs, Postgres private DNS.
# “Databricks” subnets are Azure Network only (delegation Microsoft.Databricks/workspaces) for VNet injection — not the Databricks workspace.
# Workspace, clusters, jobs: terraform/databricks → Terraform Databricks (Dev) workflow.
# No ADLS (terraform/adls), no bootstrap VM (terraform/bootstrap_vm). State: retailflow-dev-base.tfstate

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
  location    = var.azure_region
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

# NSGs for Databricks subnets (required for VNet injection – workspace needs association IDs)
resource "azurerm_network_security_group" "databricks_public" {
  name                = "${local.name_prefix}-dbw-public-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "databricks_private" {
  name                = "${local.name_prefix}-dbw-private-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Subnets for Databricks (with delegation) and for private endpoints
resource "azurerm_subnet" "public" {
  name                 = "${local.name_prefix}-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.1.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "${local.name_prefix}-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.2.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.databricks_public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.databricks_private.id
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${local.name_prefix}-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.3.0/24"]
}

# Subnet for PostgreSQL Flexible Server (VNet integration / private only). Used by terraform/postgres for Olist ingest.
resource "azurerm_subnet" "postgres" {
  name                 = "${local.name_prefix}-postgres"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.4.0/24"]

  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private DNS zone for PostgreSQL Flexible Server so Databricks (same VNet) can resolve server FQDN to private IP.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name_prefix}-postgres-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
