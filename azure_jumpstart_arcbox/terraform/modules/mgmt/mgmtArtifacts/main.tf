variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID."
}

variable "virtual_network_name" {
  type        = string
  description = "ArcBox vNET name."
}

variable "subnet_name" {
  type        = string
  description = "ArcBox subnet name."
}

variable "aks_subnet_name" {
  type        = string
  description = "ArcBox AKS subnet name."
  default     = "ArcBox-AKS-Subnet"
}

variable "dc_subnet_name" {
  type        = string
  description = "ArcBox DC subnet name."
  default     = "ArcBox-DC-Subnet"
}

variable "dr_virtual_network_name" {
  type        = string
  description = "DR Virtual network."
  default     = "ArcBox-DR-VNet"
}

variable "dr_subnet_name" {
  type        = string
  description = "ArcBox DR subnet name."
  default     = "ArcBox-DR-Subnet"
}


variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "deploy_bastion" {
  type        = bool
  description = "Choice to deploy Bastion to connect to the client VM"
  default     = false
}

variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro', 'DevOps' and 'DataOps'."
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS Server configuration."
  default = []
}

locals {
  vnet_address_space         = ["10.16.0.0/16"]
  subnet_address_prefix      = "10.16.1.0/24"
  aksSubnetPrefix            = "10.16.76.0/22"
  dcSubnetPrefix             = "10.16.2.0/24"
  drAddressPrefix            = ["172.16.0.0/16"]
  drSubnetPrefix             = "172.16.128.0/17"
  bastionSubnetName          = "AzureBastionSubnet"
  nsg_name                   = "ArcBox-NSG"
  bastion_nsg_name           = "ArcBox-Bastion-NSG"
  bastionSubnetRef           = "${azurerm_virtual_network.vnet.id}/subnets/${local.bastionSubnetName}"
  bastionName                = "ArcBox-Bastion"
  bastionSubnetIpPrefix      = "10.16.3.64/26"
  bastionPublicIpAddressName = "${local.bastionName}-PIP"

  solutions = [
    {
      name   = "Security"
      flavor = ["ITPro", "DevOps", "DataOps"]
    }
  ]
}

resource "random_string" "random" {
  length  = 13
  special = false
  numeric  = true
  upper   = false
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = local.vnet_address_space
  
  subnet {
    name           = var.subnet_name
    address_prefix = local.subnet_address_prefix
    security_group = azurerm_network_security_group.nsg.id
  }

}

resource "azurerm_virtual_network" "drVnet" {
  count               = var.deployment_flavor == "DataOps" ? 1 : 0
  name                = var.dr_virtual_network_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = local.drAddressPrefix

  subnet {
    name           = var.dr_subnet_name
    address_prefix = local.drSubnetPrefix
    security_group = azurerm_network_security_group.nsg.id
  }

}

resource "azurerm_subnet" "AzureBastionSubnet" {
  count                = var.deploy_bastion == true ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.bastionSubnetIpPrefix]
}

resource "azurerm_subnet" "aksSubnet" {
  count                = var.deployment_flavor == "DataOps" ? 1 : 0
  name                 = var.aks_subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.aksSubnetPrefix]
}

resource "azurerm_subnet" "dcSubnet" {
  count                = var.deployment_flavor == "DataOps" ? 1 : 0
  name                 = var.dc_subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.dcSubnetPrefix]
}

resource "azurerm_subnet_network_security_group_association" "BastionSubnetNsg" {
  count                     = var.deploy_bastion == true ? 1 : 0
  subnet_id                 = azurerm_subnet.AzureBastionSubnet[0].id
  network_security_group_id = azurerm_network_security_group.bastion_nsg[0].id
}

resource "azurerm_subnet_network_security_group_association" "aksSubnetNsg" {
  count                = var.deployment_flavor == "DataOps" ? 1 : 0
  subnet_id                 = azurerm_subnet.aksSubnet[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "dcSubnetNsg" {
  count                = var.deployment_flavor == "DataOps" ? 1 : 0
  subnet_id                 = azurerm_subnet.dcSubnet[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = local.nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "bastion_nsg" {
  count               = var.deploy_bastion == true ? 1 : 0
  name                = local.bastion_nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network_peering" "virtualNetworkName_peering_to_DR_vnet" {
  count                     = var.deployment_flavor == "DataOps" ? 1 : 0
  resource_group_name       = data.azurerm_resource_group.rg.name
  name                      = "peering-to-DR-vnet"
  virtual_network_name      = azurerm_virtual_network.vnet.name
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  remote_virtual_network_id = azurerm_virtual_network.drVnet[0].id
}

resource "azurerm_virtual_network_peering" "drVirtualNetworkName_peering_to_primary_vnet" {
  count                     = var.deployment_flavor == "DataOps" ? 1 : 0
  resource_group_name       = data.azurerm_resource_group.rg.name
  name                      = "peering-to-primary-vnet"
  virtual_network_name      = azurerm_virtual_network.drVnet[0].name
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_network_security_rule" "allow_k8s_80" {
  name                        = "allow_k8s_80"
  access                      = "Allow"
  priority                    = 1003
  source_address_prefix       = "*"
  destination_port_range      = "80"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_k8s_8080" {
  name                        = "allow_k8s_8080"
  access                      = "Allow"
  priority                    = 1004
  source_address_prefix       = "*"
  destination_port_range      = "8080"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_k8s_443" {
  name                        = "allow_k8s_443"
  access                      = "Allow"
  priority                    = 1005
  source_address_prefix       = "*"
  destination_port_range      = "443"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_k8s_kubelet" {
  name                        = "allow_k8s_kubelet"
  access                      = "Allow"
  priority                    = 1006
  source_address_prefix       = "*"
  destination_port_range      = "10250"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_traefik_lb_external" {
  name                        = "allow_traefik_lb_external"
  access                      = "Allow"
  priority                    = 1007
  source_address_prefix       = "*"
  destination_port_range      = "32323"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_SQLMI_traffic" {
  name                        = "allow_SQLMI_traffic"
  access                      = "Allow"
  priority                    = 1008
  source_address_prefix       = "*"
  destination_port_range      = "11433"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_Postgresql_traffic" {
  name                        = "allow_Postgresql_traffic"
  access                      = "Allow"
  priority                    = 1009
  source_address_prefix       = "*"
  destination_port_range      = "15432"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_SQLMI_mirroring_traffic" {
  name                        = "allow_SQLMI_mirroring_traffic"
  access                      = "Allow"
  priority                    = 1012
  source_address_prefix       = "*"
  destination_port_range      = "5022"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "bastion_allow_https_inbound" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_https_inbound"
  access                      = "Allow"
  priority                    = 1010
  source_address_prefix       = "Internet"
  destination_port_range      = "443"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_gateway_manager_inbound" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_gateway_manager_inbound"
  access                      = "Allow"
  priority                    = 1011
  source_address_prefix       = "GatewayManager"
  destination_port_range      = "443"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_load_balancer_inbound" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_load_balancer_inbound"
  access                      = "Allow"
  priority                    = 1012
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "443"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Inbound"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_host_comms" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_host_comms"
  access                      = "Allow"
  priority                    = 1013
  source_address_prefix       = "VirtualNetwork"
  destination_port_ranges     = ["8080", "5701"]
  source_port_range           = "*"
  protocol                    = "*"
  direction                   = "Inbound"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_ssh_rdp_outbound" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_ssh_rdp_outbound"
  access                      = "Allow"
  priority                    = 1014
  source_address_prefix       = "*"
  source_port_range           = "*"
  protocol                    = "*"
  direction                   = "Outbound"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_ranges     = ["22", "3389"]
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_azure_cloud_outbound" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_azure_cloud_outbound"
  access                      = "Allow"
  priority                    = 1015
  source_address_prefix       = "*"
  destination_port_range      = "443"
  source_port_range           = "*"
  protocol                    = "TCP"
  direction                   = "Outbound"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_get_session_info" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_get_session_info"
  access                      = "Allow"
  priority                    = 1016
  source_address_prefix       = "*"
  destination_port_ranges     = ["80", "443"]
  source_port_range           = "*"
  protocol                    = "*"
  direction                   = "Outbound"
  destination_address_prefix  = "Internet"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_bastion_comms" {
  count                       = var.deploy_bastion == true ? 1 : 0
  name                        = "bastion_allow_bastion_comms"
  access                      = "Allow"
  priority                    = 1017
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  protocol                    = "*"
  direction                   = "Outbound"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_ranges     = ["8080", "5701"]
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion_nsg[0].name
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.workspace_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "update_solution" {
  for_each = { for i, v in local.solutions : i => v
    if contains(v.flavor, var.deployment_flavor)
  }
  solution_name         = each.value.name
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value.name}"
  }
}

resource "azurerm_public_ip" "publicIpAddress" {
  count                   = var.deploy_bastion == true ? 1 : 0
  resource_group_name     = data.azurerm_resource_group.rg.name
  name                    = local.bastionPublicIpAddressName
  location                = data.azurerm_resource_group.rg.location
  allocation_method       = "Static"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
  sku                     = "Standard"

}

resource "azurerm_bastion_host" "bastionHost" {
  name                = local.bastionName
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  count               = var.deploy_bastion == true ? 1 : 0
  depends_on = [
    azurerm_public_ip.publicIpAddress
  ]
  ip_configuration {
    name                 = "IpConf"
    public_ip_address_id = azurerm_public_ip.publicIpAddress[0].id
    subnet_id            = azurerm_subnet.AzureBastionSubnet[0].id
  }

}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.workspace.id
}
