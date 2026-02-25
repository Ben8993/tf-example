output "server_id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}