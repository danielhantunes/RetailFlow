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
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.40"
    }
  }
  backend "azurerm" {
    # In CI: pass -backend-config or set via env (key=retailflow-dev-databricks.tfstate)
  }
}

provider "azurerm" {
  features {}
}

# Databricks provider: use Azure CLI auth so the credential from azure/login (OIDC) in CI is used; no client secret.
# host and azure_workspace_resource_id are set from Terraform output on second apply.
provider "databricks" {
  host                        = var.databricks_host != "" ? var.databricks_host : "https://placeholder.azuredatabricks.net"
  azure_workspace_resource_id  = var.databricks_workspace_resource_id != "" ? var.databricks_workspace_resource_id : null
  auth_type                   = "azure-cli"
}

# Read Layer 1 (platform / base) outputs (run Terraform Platform (Dev) apply first so NSG association outputs exist)
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

# Grant the Azure AD SP (used by CI for Databricks provider) Contributor on the workspace so it can call the Databricks API without manual "add to workspace".
# Set azure_principal_id to the Object ID of the Azure AD app (Enterprise Application / Service Principal object ID). See docs/DATABRICKS_AZURE_AUTH.md.
resource "azurerm_role_assignment" "databricks_workspace_contributor" {
  count                = var.azure_principal_id != "" ? 1 : 0
  scope                = azurerm_databricks_workspace.workspace.id
  role_definition_name = "Contributor"
  principal_id         = var.azure_principal_id
}
