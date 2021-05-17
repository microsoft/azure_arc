# Create an Azure Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  dns_prefix                      = try(var.dns_prefix, null) != null ? var.dns_prefix : var.name
  kubernetes_version              = var.kubernetes_version
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  default_node_pool {
    name                  = var.node_pool_name
    node_count            = var.node_pool_count
    enable_node_public_ip = false
    vm_size               = var.node_pool_vm_size
    max_pods              = var.node_pool_max_pods
    os_disk_size_gb       = var.node_pool_os_disk_size_gb
    vnet_subnet_id        = azurerm_subnet.subnet.id
    enable_auto_scaling   = var.auto_scaling_enable
    min_count             = var.auto_scaling_enable == true ? var.auto_scaling_min_count : null
    max_count             = var.auto_scaling_enable == true ? var.auto_scaling_max_count : null
  }

  dynamic "linux_profile" {
    for_each = try(var.linux_ssh_key, null) != null ? [1] : []
    content {
      admin_username = var.linux_admin_username
      ssh_key {
        key_data = var.linux_ssh_key
      }
    }
  }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    load_balancer_sku = var.network_load_balancer_sku
  }

  role_based_access_control {
    enabled = var.rbac_enabled
    dynamic "azure_active_directory" {
      for_each = var.rbac_aad == true ? [1] : []
      content {
        client_app_id     = var.rbac_aad_client_app_id
        server_app_id     = var.rbac_aad_server_app_id
        server_app_secret = var.rbac_aad_server_app_secret
        tenant_id         = var.rbac_aad_tenant_id
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    http_application_routing {
      enabled = var.http_application_routing_enabled
    }
    kube_dashboard {
      enabled = false
    }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
    }
  }

  tags = var.tags

}