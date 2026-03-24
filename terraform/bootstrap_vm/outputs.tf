output "bootstrap_vm_private_ip" {
  value       = azurerm_network_interface.bootstrap_vm.private_ip_address
  description = "Private IP (SSH via Bastion or from VNet)"
}

output "bootstrap_vm_id" {
  value       = azurerm_linux_virtual_machine.bootstrap.id
  description = "VM resource id (Bastion layer RBAC for VM login)"
}

output "bootstrap_vm_admin_password" {
  value       = var.bootstrap_vm_ssh_public_key != "" ? null : random_password.bootstrap_vm_admin.result
  sensitive   = true
  description = "Admin password when not using SSH public key"
}

output "bootstrap_vm_resource_group" {
  value = data.terraform_remote_state.base.outputs.resource_group_name
}
