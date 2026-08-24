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

output "key_vault_name" {
  value = module.key_vault.name
}

output "sql_server_fqdn" {
  value = module.sql_database.server_fqdn
}

output "sql_database_names" {
  value = module.sql_database.database_names
}

output "backend_workload_identity_client_ids" {
  description = "Client IDs used by the dev and prod pharmacy-backend Kubernetes ServiceAccounts."
  value       = { for environment, identity in azurerm_user_assigned_identity.backend : environment => identity.client_id }
}

output "migration_workload_identity_client_ids" {
  description = "Client IDs used by the environment-specific pharmacy-migration Kubernetes ServiceAccounts."
  value       = { for environment, identity in azurerm_user_assigned_identity.migration : environment => identity.client_id }
}

output "sql_bootstrap_workload_identity_client_id" {
  description = "Client ID used only by the controlled SQL access bootstrap Job."
  value       = azurerm_user_assigned_identity.sql_bootstrap.client_id
}

output "sql_access_groups" {
  description = "Stable Entra group names and object IDs consumed by the SQL access bootstrap. Membership is governed outside Terraform."
  value = {
    dev_developers = {
      display_name = azuread_group_without_members.sql_dev_developers.display_name
      object_id    = azuread_group_without_members.sql_dev_developers.object_id
    }
    prod_readers = {
      display_name = azuread_group_without_members.sql_prod_readers.display_name
      object_id    = azuread_group_without_members.sql_prod_readers.object_id
    }
    prod_admins = {
      display_name = azuread_group_without_members.sql_prod_admins.display_name
      object_id    = azuread_group_without_members.sql_prod_admins.object_id
    }
    platform_admins = {
      display_name = var.platform_admin_group_display_name
      object_id    = var.platform_admin_group_object_id
    }
  }
}

output "log_analytics_workspace_id" {
  value = module.observability.id
}
