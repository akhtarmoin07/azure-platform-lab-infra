output "server_id" {
  value = azurerm_mssql_server.this.id
}

output "server_fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_ids" {
  value = { for name, database in azurerm_mssql_database.this : name => database.id }
}

output "database_names" {
  value = keys(azurerm_mssql_database.this)
}
