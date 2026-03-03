# Layer 2 – Databricks ONLY (dev)
# This root MUST include ONLY Databricks resources. Single resource: azurerm_databricks_workspace (retailflow-dev-dbw, standard).
# The terraform_remote_state data source only reads base outputs (VNet, subnets); it is not a deployed resource.
# State: retailflow-dev-databricks.tfstate

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    # In CI: pass -backend-config or set via env (key=retailflow-dev-databricks.tfstate)
  }
}

provider "azurerm" {
  features {}
}

# Read Layer 1 (base) outputs (run Terraform Base (Dev) apply first so NSG association outputs exist)
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
  rg_name                                    = data.terraform_remote_state.base.outputs.resource_group_name
  location                                   = data.terraform_remote_state.base.outputs.location
  vnet_id                                    = data.terraform_remote_state.base.outputs.vnet_id
  public_subnet_id                           = data.terraform_remote_state.base.outputs.public_subnet_id
  private_subnet_id                          = data.terraform_remote_state.base.outputs.private_subnet_id
  public_subnet_nsg_association_id            = data.terraform_remote_state.base.outputs.public_subnet_network_security_group_association_id
  private_subnet_nsg_association_id           = data.terraform_remote_state.base.outputs.private_subnet_network_security_group_association_id
}

# Azure Databricks Workspace: retailflow-dev-dbw, standard tier
resource "azurerm_databricks_workspace" "workspace" {
  name                = "retailflow-dev-dbw"
  resource_group_name = local.rg_name
  location            = local.location
  sku                 = "standard"

  custom_parameters {
    no_public_ip            = true
    virtual_network_id      = local.vnet_id
    public_subnet_name      = split("/", local.public_subnet_id)[length(split("/", local.public_subnet_id)) - 1]
    private_subnet_name     = split("/", local.private_subnet_id)[length(split("/", local.private_subnet_id)) - 1]
    # Required by Azure when using VNet injection (must run Terraform Base apply first)
    public_subnet_network_security_group_association_id  = data.terraform_remote_state.base.outputs.public_subnet_network_security_group_association_id
    private_subnet_network_security_group_association_id = data.terraform_remote_state.base.outputs.private_subnet_network_security_group_association_id
  }

  tags = var.tags
}
