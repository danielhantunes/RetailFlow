# Unity Catalog metastore (Azure): access connector, ADLS root, metastore + workspace assignment.
# Requires: Platform, Data Lake, and Databricks workspace stacks applied first.
# State: retailflow-dev-databricks-unity-catalog.tfstate
# Destroy this stack before destroying terraform/databricks_workspace (metastore assignment).

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
  }
  backend "azurerm" {
    # CI: -backend-config key=retailflow-dev-databricks-unity-catalog.tfstate
  }
}

provider "azurerm" {
  features {}
}

# Account-level API for metastore / assignment (requires Databricks account admin for the Azure AD identity).
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
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

data "terraform_remote_state" "adls" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_adls_key
  }
}

data "terraform_remote_state" "databricks_workspace" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_databricks_workspace_key
  }
}

locals {
  rg_name  = data.terraform_remote_state.base.outputs.resource_group_name
  location = data.terraform_remote_state.base.outputs.location

  storage_account_name = data.terraform_remote_state.adls.outputs.storage_account_name
  storage_account_id     = data.terraform_remote_state.adls.outputs.storage_account_id

  # Databricks control plane ID (not the Azure resource ID).
  databricks_workspace_control_plane_id = data.terraform_remote_state.databricks_workspace.outputs.workspace_databricks_control_plane_id
}
