resource "azurerm_resource_group" "arcdemo" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "arcdemo" {
  name                = var.aks_name
  location            = azurerm_resource_group.arcdemo.location
  resource_group_name = azurerm_resource_group.arcdemo.name
  dns_prefix          = var.prefix

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    Project = "jumpstart_azure_arc_k8s"
  }

  role_based_access_control {
    enabled = true
  }
}