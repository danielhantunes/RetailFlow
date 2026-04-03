# Layer 2b – Databricks compute (dev): clusters + jobs only. Workspace is terraform/databricks_workspace.
# State: retailflow-dev-databricks-compute.tfstate
# Requires: base (Platform) + databricks_workspace applied (remote state outputs).

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
    # CI: key=retailflow-dev-databricks-compute.tfstate
  }
}

provider "azurerm" {
  features {}
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
  databricks_host                       = data.terraform_remote_state.databricks_workspace.outputs.workspace_url
  databricks_workspace_resource_id    = data.terraform_remote_state.databricks_workspace.outputs.workspace_id
}

provider "databricks" {
  host                       = local.databricks_host
  azure_workspace_resource_id = local.databricks_workspace_resource_id
  auth_type                  = "azure-cli"
}
