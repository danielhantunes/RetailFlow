# Azure Bastion (Basic) — optional layer. Deploy after Terraform Base (Dev); destroy when idle to save cost.
# State: retailflow-dev-bastion.tfstate

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    # CI: key=retailflow-dev-bastion.tfstate
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
  name_prefix = "retailflow-dev"
  base_rg     = data.terraform_remote_state.base.outputs.resource_group_name
  vnet_name   = data.terraform_remote_state.base.outputs.vnet_name
  location    = data.terraform_remote_state.base.outputs.location
}

resource "azurerm_subnet" "azure_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.base_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.azure_bastion_subnet_cidr]
}

resource "azurerm_public_ip" "bastion" {
  name                = "${local.name_prefix}-bastion-pip"
  location            = local.location
  resource_group_name = local.base_rg
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "${local.name_prefix}-bastion"
  location            = local.location
  resource_group_name = local.base_rg
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion"
    subnet_id            = azurerm_subnet.azure_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
