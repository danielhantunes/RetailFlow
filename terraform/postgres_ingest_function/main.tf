# Azure Function App for Postgres → ADLS RAW ingestion (scheduled).
# Run after Terraform Platform (Dev), Terraform Data Lake (ADLS), and Postgres. State: retailflow-postgres-ingest-function.tfstate.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    # CI: -backend-config (resource_group_name, storage_account_name, container_name, key=retailflow-postgres-ingest-function.tfstate)
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

data "terraform_remote_state" "adls" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_adls_key
  }
}

# Postgres: host and user for function app settings (password from state or variable)
data "terraform_remote_state" "postgres" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_postgres_key
  }
}

locals {
  name_prefix = "retailflow-dev-pg-ingest"
  location    = data.terraform_remote_state.base.outputs.location
  base_rg     = data.terraform_remote_state.base.outputs.resource_group_name
  vnet_name   = data.terraform_remote_state.base.outputs.vnet_name
  adls_id     = data.terraform_remote_state.adls.outputs.storage_account_id
}

# Subnet for Function App (VNet integration). Delegation required for Microsoft.Web/serverFarms.
resource "azurerm_subnet" "function" {
  name                 = "${local.name_prefix}-func"
  resource_group_name  = local.base_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.function_subnet_cidr]

  delegation {
    name = "func"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Storage account required by Azure for the Function App (internal state)
resource "azurerm_storage_account" "function" {
  name                     = replace("${local.name_prefix}sa", "-", "")
  resource_group_name      = local.base_rg
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  tags                     = var.tags
}

# Elastic Premium EP1 for VNet integration (Consumption plan does not support VNet)
resource "azurerm_service_plan" "function" {
  name                = "${local.name_prefix}-plan"
  resource_group_name  = local.base_rg
  location             = local.location
  os_type              = "Linux"
  sku_name             = "EP1"
  tags                 = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                       = "${local.name_prefix}-func"
  resource_group_name         = local.base_rg
  location                   = local.location
  service_plan_id            = azurerm_service_plan.function.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  virtual_network_subnet_id  = azurerm_subnet.function.id

  site_config {
    application_insights_connection_string = azurerm_application_insights.func.connection_string
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "POSTGRES_HOST"        = data.terraform_remote_state.postgres.outputs.postgres_host
    "POSTGRES_USER"        = data.terraform_remote_state.postgres.outputs.postgres_user
    "POSTGRES_PASSWORD"    = var.postgres_password != "" ? var.postgres_password : data.terraform_remote_state.postgres.outputs.postgres_password
    "POSTGRES_DB"          = data.terraform_remote_state.postgres.outputs.postgres_db
    "RAW_STORAGE_ACCOUNT"  = data.terraform_remote_state.adls.outputs.storage_account_name
    "RAW_CONTAINER"        = var.raw_container_name
    "POSTGRES_TIMER_SCHEDULE" = "0 */15 * * * *"
    "AzureWebJobsStorage" = azurerm_storage_account.function.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    # Python v2 programming model (function_app.py decorators): required for functions to register in the host.
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Application Insights for the function
resource "azurerm_application_insights" "func" {
  name                = "${local.name_prefix}-insights"
  resource_group_name = local.base_rg
  location             = local.location
  application_type    = "other"
  tags                = var.tags
}

# Grant function's managed identity access to ADLS (RAW container)
resource "azurerm_role_assignment" "function_adls" {
  scope                = local.adls_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
