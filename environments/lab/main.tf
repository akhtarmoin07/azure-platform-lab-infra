data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  suffix              = substr(md5(var.subscription_id), 0, 8)
  resource_group_name = "rg-${var.project_name}-lab"
}

resource "azurerm_resource_group" "platform" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

module "networking" {
  source = "../../modules/networking"

  name                = "vnet-${var.project_name}-lab"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  address_space       = var.vnet_address_space
  aks_subnet_prefixes = var.aks_subnet_prefixes
  tags                = var.tags
}

module "acr" {
  source = "../../modules/acr"

  name                = "acr${var.project_name}${local.suffix}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  sku                 = var.acr_sku
  tags                = var.tags
}

module "adls" {
  source = "../../modules/adls"

  name                = "st${var.project_name}${local.suffix}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  containers          = var.adls_containers
  tags                = var.tags
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                = "kv-${var.project_name}-${local.suffix}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.tags
}

module "observability" {
  source = "../../modules/observability"

  name                = "log-${var.project_name}-lab"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  retention_in_days   = var.log_retention_in_days
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "id-aks-${var.project_name}-control-plane"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_subnet_network_contributor" {
  scope                            = module.networking.aks_subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks_control_plane.principal_id
  skip_service_principal_aad_check = true
}

module "aks" {
  source = "../../modules/aks"

  name                       = "aks-${var.project_name}-lab"
  resource_group_name        = azurerm_resource_group.platform.name
  location                   = azurerm_resource_group.platform.location
  dns_prefix                 = "aks-${var.project_name}-lab"
  subnet_id                  = module.networking.aks_subnet_id
  control_plane_identity_id  = azurerm_user_assigned_identity.aks_control_plane.id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  node_vm_size               = var.node_vm_size
  node_count                 = var.node_count
  node_os_disk_size_gb       = var.node_os_disk_size_gb
  user_node_vm_size          = var.user_node_vm_size
  user_node_count            = var.user_node_count
  user_node_min_count        = var.user_node_min_count
  user_node_max_count        = var.user_node_max_count
  user_node_os_disk_size_gb  = var.user_node_os_disk_size_gb
  kubernetes_version         = var.kubernetes_version
  service_cidr               = var.aks_service_cidr
  dns_service_ip             = var.aks_dns_service_ip
  pod_cidr                   = var.aks_pod_cidr
  log_analytics_workspace_id = module.observability.id
  enable_container_insights  = var.enable_container_insights
  enable_azure_policy        = var.enable_azure_policy
  tags                       = var.tags

  depends_on = [
    azurerm_role_assignment.aks_subnet_network_contributor
  ]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "platform_admin_aks_admin" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.platform_admin_group_object_id
}

resource "azurerm_role_assignment" "platform_admin_aks_cluster_user" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.platform_admin_group_object_id
}

resource "azurerm_role_assignment" "platform_admin_key_vault_admin" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.platform_admin_group_object_id
}

resource "azurerm_role_assignment" "aks_key_vault_secrets_user" {
  scope                            = module.key_vault.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = module.aks.key_vault_secrets_provider_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "platform_admin_adls_data_owner" {
  scope                = module.adls.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.platform_admin_group_object_id
}

resource "azurerm_consumption_budget_subscription" "lab" {
  name            = "budget-${var.project_name}-monthly"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }
}
