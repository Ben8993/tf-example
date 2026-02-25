resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.server_name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.virtual_network_id
  tags                  = var.tags
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version                = var.postgresql_version
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}