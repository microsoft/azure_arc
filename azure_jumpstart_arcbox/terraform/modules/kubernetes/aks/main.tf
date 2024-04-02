variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}
variable "aks_cluster_name" {
  type        = string
  description = "The name of the Kubernetes cluster resource"
  default     = "ArcBox-AKS-Data"
}

variable "aks_dr_cluster_name" {
  type        = string
  description = "The name of the DR Kubernetes cluster resource"
  default     = "ArcBox-AKS-DR-Data"
}

variable "dns_prefix_primary" {
  type        = string
  description = "Optional DNS prefix to use with hosted Kubernetes API server FQDN"
  default     = "arcdata"
}

variable "dns_prefix_secondary" {
  type        = string
  description = "Optional DNS prefix to use with hosted Kubernetes API server FQDN"
  default     = "arcdata"
}

variable "agent_count" {
  type        = number
  description = "The number of nodes for the cluster"
  default     = 3
}

variable "agent_vm_size" {
  type        = string
  description = "The size of the VM."
  default     = "Standard_D8s_v4"
}

variable "linux_admin_Username" {
  type        = string
  description = "User name for the Linux Virtual Machines"
  default     = "arcdemo"
}

variable "ssh_rsa_public_key" {
  type        = string
  description = "Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm"
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID."
}

variable "spn_client_secret" {
  type        = string
  description = "Arc Service Principal client secret."
  sensitive   = true
}

variable "spn_tenant_id" {
  type        = string
  description = "Tenant Id"
}



variable "enable_rbac" {
  type        = bool
  description = "boolean flag to turn on and off of RBAC"
  default     = true
}

variable "os_type" {
  type        = string
  description = "The type of operating system"
  default     = "Linux"
}

variable "Kubernetes_version" {
  type        = string
  description = "The version of Kubernetes"
  default     = "1.28.5"
}

locals {
  service_cidr_primary         = "10.20.64.0/19"
  dns_service_ip_primary       = "10.20.64.10"
  docker_bridge_cidr_primary   = "172.17.0.1/16"
  service_cidr_secondary       = "172.20.64.0/19"
  dns_service_ip_secondary     = "172.20.64.10"
  docker_bridge_cidr_secondary = "192.168.0.1/16"
  virtual_network_name         = "ArcBox-VNet"
  aks_subnet_name              = "ArcBox-AKS-Subnet"
  dr_virtual_network_name      = "ArcBox-DR-VNet"
  dr_subnet_name               = "ArcBox-DR-Subnet"
}

data "azurerm_subscription" "primary" {
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_subnet" "aks_subnet" {
  name                 = local.aks_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "aks_dr_subnet" {
  name                 = local.dr_subnet_name
  virtual_network_name = local.dr_virtual_network_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

resource "azurerm_kubernetes_cluster" "aks_primary" {
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  name                = var.aks_cluster_name
  kubernetes_version                = var.Kubernetes_version
  role_based_access_control_enabled = var.enable_rbac
  dns_prefix                        = var.dns_prefix_primary
  default_node_pool {
    name            = "agentpool"
    vm_size         = var.agent_vm_size
    node_count      = var.agent_count
    type            = "VirtualMachineScaleSets"
    vnet_subnet_id  = data.azurerm_subnet.aks_subnet.id
  }
  network_profile {
    network_plugin     = "azure"
    service_cidr       = local.service_cidr_primary
    dns_service_ip     = local.dns_service_ip_primary
    docker_bridge_cidr = local.docker_bridge_cidr_primary
  }
  linux_profile {
    admin_username = var.linux_admin_Username
    ssh_key {
      key_data = file(var.ssh_rsa_public_key)
    }
  }
  azure_active_directory_role_based_access_control {
    managed   = true
    tenant_id = var.spn_tenant_id
  }
  service_principal {
    client_id     = var.spn_client_id
    client_secret = var.spn_client_secret
  }
}

resource "azurerm_kubernetes_cluster" "aks_dr_primary" {
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  name                = var.aks_dr_cluster_name
  kubernetes_version                = var.Kubernetes_version
  role_based_access_control_enabled = var.enable_rbac
  dns_prefix                        = var.dns_prefix_primary
  default_node_pool {
    name            = "agentpool"
    vm_size         = var.agent_vm_size
    node_count      = var.agent_count
    type            = "VirtualMachineScaleSets"
    vnet_subnet_id  = data.azurerm_subnet.aks_dr_subnet.id
  }
  network_profile {
    network_plugin     = "azure"
    service_cidr       = local.service_cidr_secondary
    dns_service_ip     = local.dns_service_ip_secondary
    docker_bridge_cidr = local.docker_bridge_cidr_secondary
  }
  linux_profile {
    admin_username = var.linux_admin_Username
    ssh_key {
      key_data = file(var.ssh_rsa_public_key)
    }
  }
  service_principal {
    client_id     = var.spn_client_id
    client_secret = var.spn_client_secret
  }
  azure_active_directory_role_based_access_control {
    managed   = true
    tenant_id = var.spn_tenant_id
  }
}
