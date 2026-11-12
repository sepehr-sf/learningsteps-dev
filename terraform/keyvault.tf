
# Get current Azure identity and tenant information
data "azurerm_client_config" "current" {}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true
}

# Grant Terraform identity permission to manage Key Vault secrets
resource "azurerm_role_assignment" "terraform_keyvault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store PostgreSQL connection string
resource "azurerm_key_vault_secret" "postgres_connection" {
  name         = "postgres-connection-string"
  key_vault_id = azurerm_key_vault.main.id

  value = "postgresql://${var.postgres_admin_username}:${urlencode(var.postgres_admin_password)}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/learning_journal?sslmode=require"

  depends_on = [
    azurerm_role_assignment.terraform_keyvault,
    azurerm_postgresql_flexible_server_database.learningsteps
  ]
}


# Allow AKS Key Vault Secrets Provider to retrieve secrets
resource "azurerm_role_assignment" "aks_keyvault_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"

  principal_id = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}

