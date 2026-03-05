output "postgres_host" {
  description = "PostgreSQL Flexible Server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_db" {
  description = "Database name to use (created by workflow after apply)"
  value       = "retailflow"
}

output "postgres_user" {
  description = "PostgreSQL administrator login"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "postgres_password" {
  description = "PostgreSQL administrator password"
  value       = random_password.postgres_admin.result
  sensitive   = true
}
