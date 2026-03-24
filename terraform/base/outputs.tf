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

output "private_endpoints_subnet_id" {
  value       = azurerm_subnet.private_endpoints.id
  description = "Subnet for private endpoints (ADLS PE, etc.) — used by terraform/adls"
}

output "private_endpoints_subnet_name" {
  value       = azurerm_subnet.private_endpoints.name
  description = "Name of the private-endpoints subnet (terraform/base: retailflow-dev-pe in default layout)"
}

output "public_subnet_network_security_group_association_id" {
  value = azurerm_subnet_network_security_group_association.public.id
}

output "private_subnet_network_security_group_association_id" {
  value = azurerm_subnet_network_security_group_association.private.id
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
