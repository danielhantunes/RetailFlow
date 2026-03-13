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

# For terraform/postgres (ingest): private PostgreSQL in same VNet as Databricks
output "postgres_delegated_subnet_id" {
  value = azurerm_subnet.postgres.id
}

output "postgres_private_dns_zone_id" {
  value = azurerm_private_dns_zone.postgres.id
}

# Bootstrap VM – private only (SSH via Bastion or VPN; runner reaches GitHub outbound)
output "bootstrap_vm_private_ip" {
  value       = azurerm_network_interface.bootstrap_vm.private_ip_address
  description = "Private IP for SSH via Bastion or from within VNet"
}

output "bootstrap_vm_admin_password" {
  value       = var.bootstrap_vm_ssh_public_key != "" ? null : random_password.bootstrap_vm_admin.result
  sensitive   = true
  description = "Bootstrap VM admin password (null when bootstrap_vm_ssh_public_key is set; use SSH key then)"
}
