resource "azurerm_mssql_server" "this" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = var.entra_admin_login_username
    object_id                   = var.entra_admin_object_id
    tenant_id                   = var.tenant_id
    azuread_authentication_only = true
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "this" {
  for_each = var.database_names

  name                                = each.value
  server_id                           = azurerm_mssql_server.this.id
  sku_name                            = var.database_sku_name
  max_size_gb                         = var.database_max_size_gb
  collation                           = "SQL_Latin1_General_CP1_CI_AS"
  storage_account_type                = "Local"
  transparent_data_encryption_enabled = true
  tags                                = var.tags

  short_term_retention_policy {
    retention_days = 7
  }
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "link-${var.server_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pep-${var.server_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.server_name}"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-private-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
