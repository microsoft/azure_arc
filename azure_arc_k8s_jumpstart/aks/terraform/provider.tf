#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    azurerm = "~> 2.9.0"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}