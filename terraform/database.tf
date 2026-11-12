
# Azure Database for PostgreSQL - Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.postgres_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  version = "16"

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  # Private networking
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  public_network_access_enabled = false

  # Development configuration 
  sku_name   = "GP_Standard_D2ds_v6"
  zone       = "2"
  storage_mb = 32768

  backup_retention_days = 7

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]
}

# LearningSteps application database
resource "azurerm_postgresql_flexible_server_database" "learningsteps" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
