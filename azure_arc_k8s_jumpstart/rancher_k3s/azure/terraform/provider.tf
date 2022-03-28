#
# Providers Configuration
#

terraform {
  required_version = "~> 1.0.11"
  required_providers {
    azurerm = "~> 2.97.0"
  }
}

# Configure the Microsoft Azure Resource Manager Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}