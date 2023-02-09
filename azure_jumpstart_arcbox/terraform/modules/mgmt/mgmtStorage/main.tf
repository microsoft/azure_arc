variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "storage_account_type" {
  type        = string
  description = "Storage Account type"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_type)
    error_message = "Valid values for var: storage_account_type are (Standard or Premium)."
  }
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "random_string" "random" {
  length  = 13
  special = false
  numeric  = true
  upper   = false
}

locals {
  storage_account_name = "arcbox${random_string.random.result}"
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = var.storage_account_type
  account_replication_type = "LRS"
  enable_https_traffic_only = true
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}
