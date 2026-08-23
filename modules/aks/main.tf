resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
  azure_policy_enabled              = var.enable_azure_policy
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  default_node_pool {
    name                         = "system"
    node_count                   = var.node_count
    vm_size                      = var.node_vm_size
    vnet_subnet_id               = var.subnet_id
    type                         = "VirtualMachineScaleSets"
    os_disk_size_gb              = var.node_os_disk_size_gb
    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.control_plane_identity_id]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    pod_cidr            = var.pod_cidr
  }

  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []

    content {
      log_analytics_workspace_id      = var.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !var.enable_container_insights || var.log_analytics_workspace_id != null
      error_message = "A Log Analytics workspace ID is required when Container Insights is enabled."
    }
  }
}
