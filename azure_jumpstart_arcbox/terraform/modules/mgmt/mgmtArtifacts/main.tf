variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
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

locals {
  vnet_address_space    = ["172.16.0.0/16"]
  subnet_address_prefix = "172.16.1.0/24"
  solutions             = ["Updates", "VMInsights", "ChangeTracking", "Security"]
}

resource "random_string" "random" {
  length  = 13
  special = false
  number  = true
  upper   = false
}

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
  }
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

output "workspace_id" {
  value = azurerm_log_analytics_workspace.workspace.id
}
