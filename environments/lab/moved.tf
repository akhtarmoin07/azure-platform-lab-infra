moved {
  from = azurerm_role_assignment.current_user_aks_admin
  to   = azurerm_role_assignment.platform_admin_aks_admin
}

moved {
  from = azurerm_role_assignment.current_user_aks_cluster_user
  to   = azurerm_role_assignment.platform_admin_aks_cluster_user
}

moved {
  from = azurerm_role_assignment.current_user_key_vault_admin
  to   = azurerm_role_assignment.platform_admin_key_vault_admin
}

moved {
  from = azurerm_role_assignment.current_user_adls_data_owner
  to   = azurerm_role_assignment.platform_admin_adls_data_owner
}
