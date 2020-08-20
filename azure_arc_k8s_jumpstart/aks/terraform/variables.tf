variable "resource_group_name" {
  description = "The Azure Resource Group this AKS Managed Kubernetes Cluster should be provisioned"
  default     = "Arc-AKS-Demo"
}

variable "aks_name" {
  description = "This AKS Managed Kubernetes Cluster name"
  default     = "Arc-AKS-Demo"
}

variable "prefix" {
  description = "A prefix used for all resources for this AKS Managed Kubernetes Cluster"
  default     = "arcaksdemo"
}

variable "location" {
  description = "The Azure Region in which all resources for this AKS Managed Kubernetes Cluster should be provisioned"
  default     = "East US"
}

variable "kubernetes_version" {
  description = "Kubernetes version deployed"
  default     = "1.18.4"
}

variable "node_count" {
  description = "The number of Azure VMs for this AKS Managed Kubernetes Cluster node pool"
  default     = 1
}

variable "vm_size" {
  description = "The Azure VM size for this AKS Managed Kubernetes Cluster node pool"
  default     = "Standard_DS2_v2"
}

variable "client_id" {
  description = "The Client ID for the Service Principal to use for this AKS Managed Kubernetes Cluster"
}

variable "client_secret" {
  description = "The Client Secret for the Service Principal to use for this AKS Managed Kubernetes Cluster"
}