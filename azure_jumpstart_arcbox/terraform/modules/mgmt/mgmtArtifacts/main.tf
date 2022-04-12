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

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "deploy_bastion" {
  type       = bool
  description = "Choice to deploy Bastion to connect to the client VM"
  default = false
}

variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro', and 'DevOps'."
}

locals {
  vnet_address_space    = ["172.16.0.0/16"]
  subnet_address_prefix = "172.16.1.0/24"
  solutions             = ["Updates", "VMInsights", "ChangeTracking", "Security"]
  bastionSubnetName     = "AzureBastionSubnet"
  bastionSubnetRef      = "${azurerm_virtual_network.vnet.id}/subnets/${local.bastionSubnetName}"
  bastionName           = "ArcBox-Bastion"
  bastionSubnetIpPrefix = "172.16.3.64/26"
  bastionPublicIpAddressName = "${local.bastionName}-PIP"
  inbound_tcp_rules      = [
        {
            name                   = "allow_k8s_6443"
            source_address_prefix  = "*"
            destination_port_range = "6443"
        },
        {
            name                   = "allow_k8s_80"
            source_address_prefix  = "*"
            destination_port_range = "80"
        },
        {
            name                   = "allow_k8s_8080"
            source_address_prefix  = "*"
            destination_port_range = "8080"
        },
        {
            name                   = "allow_k8s_443"
            source_address_prefix  = "*"
            destination_port_range = "443"
        },
        {
            name                   = "allow_k8s_kubelet"
            source_address_prefix  = "*"
            destination_port_range = "10250"
        },
        {
            name                   = "allow_traefik_lb_external"
            source_address_prefix  = "*"
            destination_port_range = "32323"
        }
    ]
}

resource "random_string" "random" {
  length  = 13
  special = false
  number  = true
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

  subnet {
    name           = "AzureBastionSubnet"
    address_prefix = local.bastionSubnetIpPrefix
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = local.nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "nsg_rules" {
  for_each                    = { for i, v in local.inbound_tcp_rules: i => v }
  name                        = each.value.name
  priority                    = (index(local.inbound_tcp_rules, each.value) + 1001)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.workspace_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "update_solution" {
  for_each              = toset(local.solutions)
  solution_name         = "${each.value}"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }
}

resource "azurerm_automation_account" "automation" {
  name                = "ArcBox-Automation-${random_string.random.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_log_analytics_linked_service" "linked_service" {
  resource_group_name = data.azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  read_access_id      = azurerm_automation_account.automation.id
}

resource "azurerm_public_ip" "publicIpAddress" {
  count               = var.deploy_bastion == true ? 1: 0
  resource_group_name = data.azurerm_resource_group.rg.name
  name                = local.bastionPublicIpAddressName
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  ip_version          = "IPv4"
  idle_timeout_in_minutes = 4
  sku                 = "Standard"

}

resource "azurerm_bastion_host" "bastionHost" {
  name                = local.bastionName
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  count               = var.deploy_bastion == true ? 1: 0
  depends_on = [
    azurerm_public_ip.publicIpAddress
  ]
  ip_configuration {
    name = "IpConf"
    public_ip_address_id = azurerm_public_ip.publicIpAddress[0].id
    subnet_id = local.bastionSubnetRef
  }

}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.workspace.id
}
