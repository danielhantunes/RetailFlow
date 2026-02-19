# Terraform remote state bootstrap
# Creates resource group, storage account (with blob versioning), and private container.
# Run once per subscription/prefix; use local state or -backend=false.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "local" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tfstate" {
  name     = "${var.name_prefix}-tfstate-rg"
  location = var.azure_region
  tags     = var.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                     = replace("${var.name_prefix}tfstate", "-", "")
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type  = "private"
}
