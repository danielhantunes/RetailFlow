# RetailFlow - Main Terraform
# Provisions Azure + Databricks for dev/stg/prod via workspaces or tfvars

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.40"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
  }
  backend "azurerm" {
    # Populate after provisioning state backend via GitHub Actions (OIDC): run Provision Terraform State Backend workflow, then set:
    # resource_group_name  = "<output from workflow or terraform/backend>"
    # storage_account_name = "<output from workflow or terraform/backend>"
    # container_name       = "tfstate"
    # key                  = "retailflow.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

provider "databricks" {
  host                        = module.databricks.workspace_url
  azure_workspace_resource_id = module.databricks.workspace_id
}

data "azurerm_client_config" "current" {}

locals {
  env = var.environment
  name_prefix = "retailflow-${local.env}"
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = var.azure_region
}

# Databricks workspace
module "databricks" {
  source = "./modules/databricks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_prefix         = local.name_prefix
  environment         = local.env
  sku                 = var.databricks_sku
  # networking placeholders
  virtual_network_id  = var.create_networking ? module.networking[0].vnet_id : null
  private_subnet_id  = var.create_networking ? module.networking[0].private_subnet_id : null
  public_subnet_id   = var.create_networking ? module.networking[0].public_subnet_id : null
}

# Storage (ADLS Gen2) for RAW and processed
module "storage" {
  source = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_prefix         = local.name_prefix
  containers         = ["raw", "processed"]
  databricks_workspace_id = module.databricks.workspace_id
  databricks_workspace_principal_id = module.databricks.workspace_storage_principal_id
}

# Key Vault for secrets
module "key_vault" {
  source = "./modules/key_vault"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  name_prefix           = local.name_prefix
  tenant_id             = data.azurerm_client_config.current.tenant_id
  databricks_workspace_id = module.databricks.workspace_id
}

# Optional: VNet for private link / secure connectivity
module "networking" {
  count  = var.create_networking ? 1 : 0
  source = "./modules/networking"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name_prefix         = local.name_prefix
}

# Outputs
output "databricks_workspace_url" {
  value = module.databricks.workspace_url
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "key_vault_name" {
  value = module.key_vault.key_vault_name
}

output "raw_container_name" {
  value = "raw"
}
