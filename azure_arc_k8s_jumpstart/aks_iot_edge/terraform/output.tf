# Logs Workspaces
output "id-log-workspace" {
  description = "Output the object ID"
  value       = azurerm_log_analytics_workspace.log_analytics.id
}

output "workspace_id" {
  description = "Output the object ID"
  value       = azurerm_log_analytics_workspace.log_analytics.workspace_id
}

# Virtual Network 
output "vnet_id" {
  description = "The id of the newly created vNet"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The Name of the newly created vNet"
  value       = azurerm_virtual_network.vnet.name
}

#IoT Hub
output "iothub_id" {
  description = "The id of the newly created IoT Hub"
  value       = azurerm_iothub.iot.id
}

output "iothub_name" {
  description = "The name of the newly created IoT Hub"
  value       = azurerm_iothub.iot.name
}

#Kubernetes

output "id" {
  description = "The Kubernetes Managed Cluster ID."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "fqdn" {
  description = "The FQDN of the Azure Kubernetes Managed Cluster."
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_admin_config" {
  description = "A kube_admin_config block as defined below. This is only available when Role Based Access Control with Azure Active Directory is enabled."
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config
  sensitive   = true
}

output "kube_config" {
  description = "Cluster Kubernetes Configuration object"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "node_resource_group" {
  description = "The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster."
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}