data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  suffix              = substr(md5(var.subscription_id), 0, 8)
  resource_group_name = "rg-${var.project_name}-lab"
}

resource "azuread_group_without_members" "sql_dev_developers" {
  display_name            = "${var.sql_access_group_prefix}-dev-developers"
  description             = "Developers with controlled data access to the pharmacy development database."
  security_enabled        = true
  prevent_duplicate_names = true
}

resource "azuread_group_without_members" "sql_prod_readers" {
  display_name            = "${var.sql_access_group_prefix}-prod-readers"
  description             = "Engineers with read-only troubleshooting access to the pharmacy production-pattern database."
  security_enabled        = true
  prevent_duplicate_names = true
}

resource "azuread_group_without_members" "sql_prod_admins" {
  display_name            = "${var.sql_access_group_prefix}-prod-admins"
  description             = "Exceptional production-pattern database administrators; use PIM/JIT membership in production."
  security_enabled        = true
  prevent_duplicate_names = true
}

resource "azurerm_resource_group" "platform" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

module "networking" {
  source = "../../modules/networking"

  name                             = "vnet-${var.project_name}-lab"
  resource_group_name              = azurerm_resource_group.platform.name
  location                         = azurerm_resource_group.platform.location
  address_space                    = var.vnet_address_space
  aks_subnet_prefixes              = var.aks_subnet_prefixes
  private_endpoint_subnet_prefixes = var.private_endpoint_subnet_prefixes
  tags                             = var.tags
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

  name                       = "kv-${var.project_name}-${local.suffix}"
  resource_group_name        = azurerm_resource_group.platform.name
  location                   = azurerm_resource_group.platform.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  virtual_network_id         = module.networking.vnet_id
  tags                       = var.tags
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

# AzureRM does not yet expose the AKS managed Gateway API installation and the
# Application Routing Istio implementation. AzAPI patches only these new
# ingress-profile properties while the existing AzureRM module retains
# ownership of the cluster and its node pool.
resource "azapi_update_resource" "aks_gateway_api" {
  type        = "Microsoft.ContainerService/managedClusters@2026-02-01"
  resource_id = module.aks.id

  body = {
    properties = {
      ingressProfile = {
        gatewayAPI = {
          installation = var.enable_gateway_api ? "Standard" : "Disabled"
        }
        webAppRouting = {
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = var.enable_app_routing_istio ? "Enabled" : "Disabled"
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = !var.enable_app_routing_istio || var.enable_gateway_api
      error_message = "Application Routing Istio requires the AKS managed Gateway API installation."
    }
  }
}

resource "azurerm_user_assigned_identity" "sql_bootstrap" {
  name                = "id-${var.project_name}-sql-bootstrap"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = merge(var.tags, { purpose = "sql-access-bootstrap" })
}

resource "azurerm_user_assigned_identity" "application_delivery" {
  name                = "id-${var.project_name}-application-delivery"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  tags = merge(var.tags, {
    purpose = "application-container-delivery"
  })
}

module "sql_database" {
  source = "../../modules/sql-database"

  server_name                = "sql-${var.project_name}-${local.suffix}"
  resource_group_name        = azurerm_resource_group.platform.name
  location                   = azurerm_resource_group.platform.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  entra_admin_login_username = azurerm_user_assigned_identity.sql_bootstrap.name
  entra_admin_object_id      = azurerm_user_assigned_identity.sql_bootstrap.principal_id
  database_names             = ["pharmacy-dev", "pharmacy-prod"]
  database_sku_name          = var.sql_database_sku_name
  database_max_size_gb       = var.sql_database_max_size_gb
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  virtual_network_id         = module.networking.vnet_id
  tags                       = var.tags
}

resource "azurerm_user_assigned_identity" "backend" {
  for_each = toset(["dev", "prod"])

  name                = "id-${var.project_name}-backend-${each.key}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = merge(var.tags, { environment = each.key })
}

resource "azurerm_user_assigned_identity" "migration" {
  for_each = toset(["dev", "prod"])

  name                = "id-${var.project_name}-migration-${each.key}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = merge(var.tags, { environment = each.key, purpose = "database-schema-migration" })
}

resource "azurerm_federated_identity_credential" "backend" {
  for_each = azurerm_user_assigned_identity.backend

  name      = "fic-${var.project_name}-backend-${each.key}"
  parent_id = each.value.id
  issuer    = module.aks.oidc_issuer_url
  subject   = "system:serviceaccount:${each.key}:pharmacy-backend"
  audience  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "migration" {
  for_each = azurerm_user_assigned_identity.migration

  name      = "fic-${var.project_name}-migration-${each.key}"
  parent_id = each.value.id
  issuer    = module.aks.oidc_issuer_url
  subject   = "system:serviceaccount:${each.key}:pharmacy-migration"
  audience  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "sql_bootstrap" {
  name      = "fic-${var.project_name}-sql-bootstrap"
  parent_id = azurerm_user_assigned_identity.sql_bootstrap.id
  issuer    = module.aks.oidc_issuer_url
  subject   = "system:serviceaccount:platform-system:sql-access-bootstrap"
  audience  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "application_delivery" {
  name                      = "fic-${var.project_name}-application-delivery"
  user_assigned_identity_id = azurerm_user_assigned_identity.application_delivery.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:akhtarmoin07@62751495/azure-platform-lab-apps@1343618508:environment:lab"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "backend_key_vault_secrets_user" {
  for_each = azurerm_user_assigned_identity.backend

  scope                            = module.key_vault.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = each.value.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "terraform_automation_acr_push" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPush"
  principal_id                     = data.azurerm_client_config.current.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "application_delivery_acr_push" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPush"
  principal_id                     = azurerm_user_assigned_identity.application_delivery.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "terraform_automation_aks_cluster_user" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "terraform_automation_aks_rbac_admin" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
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
