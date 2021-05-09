terraform {
  required_version = "> 0.12"
}

provider "azurerm" {
  version = "~> 2.40.0"
  features {}
}

provider "azuread" {
  version = "~> 1.0"
}

provider "kubernetes" {
  version                = "~> 2.0.3"
  load_config_file       = false
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}