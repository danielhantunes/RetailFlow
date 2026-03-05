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

resource "random_password" "postgres_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "postgres" {
  name     = var.resource_group_name
  location = var.azure_region
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
  zone                   = var.zone

  public_network_access_enabled = true

  tags = var.tags
}

# Allow all IPv4 for ephemeral CI (GitHub Actions runners); destroy removes the server.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "allow-all-ip"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Database "retailflow" is created by the ingestion workflow (psql/Python) after apply.
# Terraform only provisions the server; default DB is "postgres".
