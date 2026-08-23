output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "aks_name" {
  value = module.aks.name
}

output "aks_control_plane_identity_id" {
  value = azurerm_user_assigned_identity.aks_control_plane.id
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "adls_name" {
  value = module.adls.name
}

output "adls_dfs_endpoint" {
  value = module.adls.primary_dfs_endpoint
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "log_analytics_workspace_id" {
  value = module.observability.id
}
