# On-demand bootstrap VM (Olist CSV load, toolbox, psql). Deploy after Terraform Platform (Dev).
# State: retailflow-dev-bootstrap-vm.tfstate

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
  backend "azurerm" {}
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
  location    = data.terraform_remote_state.base.outputs.location
  vnet_name   = data.terraform_remote_state.base.outputs.vnet_name
}

resource "azurerm_subnet" "bootstrap_vm" {
  name                 = "${local.name_prefix}-bootstrap-vm"
  resource_group_name  = local.base_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = ["10.139.5.0/24"]
}

resource "azurerm_network_security_group" "bootstrap_vm" {
  name                = "${local.name_prefix}-bootstrap-vm-nsg"
  location            = local.location
  resource_group_name = local.base_rg
  tags                = var.tags
}

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
  resource_group_name         = local.base_rg
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
  resource_group_name         = local.base_rg
  network_security_group_name = azurerm_network_security_group.bootstrap_vm.name
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
  location            = local.location
  resource_group_name = local.base_rg

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bootstrap_vm.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "bootstrap" {
  name                            = "${local.name_prefix}-bootstrap-vm"
  location                        = local.location
  resource_group_name             = local.base_rg
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

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "bootstrap_aad_ssh_login" {
  count                = var.bootstrap_vm_enable_entra_login ? 1 : 0
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.bootstrap.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}
