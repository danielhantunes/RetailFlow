output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "public_subnet_id" {
  value = azurerm_subnet.public.id
}

output "private_subnet_id" {
  value = azurerm_subnet.private.id
}

output "public_subnet_network_security_group_association_id" {
  value = azurerm_subnet_network_security_group_association.public.id
}

output "private_subnet_network_security_group_association_id" {
  value = azurerm_subnet_network_security_group_association.private.id
}

output "storage_account_name" {
  value = azurerm_storage_account.dls.name
}

output "storage_account_id" {
  value = azurerm_storage_account.dls.id
}

output "location" {
  value = azurerm_resource_group.rg.location
}
