output "bastion_host_name" {
  value       = azurerm_bastion_host.main.name
  description = "Azure Bastion name. Portal → VM → Connect → Bastion → SSH"
}

output "bastion_public_ip" {
  value       = azurerm_public_ip.bastion.ip_address
  description = "Bastion public IP (reference only)"
}

output "resource_group_name" {
  value       = local.base_rg
  description = "Resource group containing Bastion (same as base)"
}
