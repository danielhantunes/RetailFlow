# Azure PostgreSQL Flexible Server for Olist dataset ingestion
# State stored in Azure (backend config from CI). Use plan/apply/destroy or full ingest from workflow.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  backend "azurerm" {
    # In CI: pass -backend-config (resource_group_name, storage_account_name, container_name, key=retailflow-ingest-pg.tfstate)
  }
}

provider "azurerm" {
  features {}
}

# Read platform (base) state for delegated subnet + private DNS. Run Terraform Platform (Dev) apply first.
data "terraform_remote_state" "base" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_base_key
  }
}

resource "random_password" "postgres_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Region must match base (required for VNet delegated subnet). If you get LocationIsOfferRestricted,
# request a quota increase for PostgreSQL in that region or deploy base in an allowed region (default: East US 2).
resource "azurerm_resource_group" "postgres" {
  name     = var.resource_group_name
  location = data.terraform_remote_state.base.outputs.location
  tags     = var.tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = var.server_name
  resource_group_name    = azurerm_resource_group.postgres.name
  location               = azurerm_resource_group.postgres.location
  version                = var.postgres_version
  administrator_login    = var.administrator_login
  administrator_password = random_password.postgres_admin.result
  sku_name               = var.sku_name
  storage_mb             = var.storage_mb
  zone = var.zone

  # Private only: delegated subnet + private DNS from base (same VNet as Databricks). No public IP.
  delegated_subnet_id           = data.terraform_remote_state.base.outputs.postgres_delegated_subnet_id
  private_dns_zone_id           = data.terraform_remote_state.base.outputs.postgres_private_dns_zone_id
  public_network_access_enabled = false

  tags = var.tags
}

# Database "retailflow" is created by ingestion. Run ingestion from Databricks (same VNet).
