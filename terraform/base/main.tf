# Layer 1 – Base Infrastructure ONLY (dev)
# Resource Group, VNet, Subnets, ADLS Gen2, Private Endpoint, Bootstrap VM (self-hosted runner for Olist COPY).
# State: retailflow-dev-base.tfstate

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
    # In CI: pass -backend-config or set via env (resource_group_name, storage_account_name, container_name, key=retailflow-dev-base.tfstate)
  }
}

provider "azurerm" {
  features {}
}

locals {
  name_prefix = "retailflow-dev"
  location     = var.azure_region
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = local.location
  tags     = var.tags
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  address_space       = ["10.139.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# NSGs for Databricks subnets (required for VNet injection – workspace needs association IDs)
resource "azurerm_network_security_group" "databricks_public" {
  name                = "${local.name_prefix}-dbw-public-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "databricks_private" {
  name                = "${local.name_prefix}-dbw-private-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Subnets for Databricks (with delegation) and for private endpoints
resource "azurerm_subnet" "public" {
  name                 = "${local.name_prefix}-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.1.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "${local.name_prefix}-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.2.0/24"]

  delegation {
    name = "databricks"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.databricks_public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.databricks_private.id
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${local.name_prefix}-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.3.0/24"]
}

# Subnet for PostgreSQL Flexible Server (VNet integration / private only). Used by terraform/postgres for Olist ingest.
resource "azurerm_subnet" "postgres" {
  name                 = "${local.name_prefix}-postgres"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.4.0/24"]

  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private DNS zone for PostgreSQL Flexible Server so Databricks (same VNet) can resolve server FQDN to private IP.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name_prefix}-postgres-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id   = azurerm_virtual_network.vnet.id
}

# Azure Data Lake Storage Gen2 (name: retailflowdevdls, hierarchical namespace)
resource "azurerm_storage_account" "dls" {
  name                     = "retailflowdevdls"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each           = toset(var.data_lake_containers)
  name               = each.value
  storage_account_id = azurerm_storage_account.dls.id
}

# Private endpoint for storage (blob)
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.name_prefix}-dls-blob-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${local.name_prefix}-dls-blob-psc"
    private_connection_resource_id = azurerm_storage_account.dls.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = var.tags
}

# Bootstrap VM: self-hosted runner for Olist CSV → PostgreSQL COPY. Private only (same VNet as Postgres). Optional browser SSH: deploy Azure Bastion via terraform/bastion + Terraform Bastion (Dev) workflow (destroy when idle to save cost).
resource "azurerm_subnet" "bootstrap_vm" {
  name                 = "${local.name_prefix}-bootstrap-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.139.5.0/24"]
}

resource "azurerm_network_security_group" "bootstrap_vm" {
  name                = "${local.name_prefix}-bootstrap-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# SSH from VNet only (e.g. Azure Bastion or another VM in the VNet)
resource "azurerm_network_security_rule" "bootstrap_vm_ssh" {
  name                        = "allow-ssh-from-vnet"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "10.139.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bootstrap_vm.name
}

resource "azurerm_network_security_rule" "bootstrap_vm_outbound" {
  name                        = "allow-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.bootstrap_vm.name
}

resource "azurerm_subnet_network_security_group_association" "bootstrap_vm" {
  subnet_id                 = azurerm_subnet.bootstrap_vm.id
  network_security_group_id = azurerm_network_security_group.bootstrap_vm.id
}

resource "random_password" "bootstrap_vm_admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}?:"
}

resource "azurerm_network_interface" "bootstrap_vm" {
  name                = "${local.name_prefix}-bootstrap-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bootstrap_vm.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "bootstrap" {
  name                            = "${local.name_prefix}-bootstrap-vm"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.bootstrap_vm_size
  admin_username                  = var.bootstrap_vm_admin_username
  admin_password                  = var.bootstrap_vm_ssh_public_key != "" ? null : random_password.bootstrap_vm_admin.result
  disable_password_authentication = var.bootstrap_vm_ssh_public_key != ""
  network_interface_ids           = [azurerm_network_interface.bootstrap_vm.id]

  dynamic "admin_ssh_key" {
    for_each = var.bootstrap_vm_ssh_public_key != "" ? [1] : []
    content {
      username   = var.bootstrap_vm_admin_username
      public_key = var.bootstrap_vm_ssh_public_key
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = var.tags
}
