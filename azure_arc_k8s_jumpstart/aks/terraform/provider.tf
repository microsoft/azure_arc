#
# Providers Configuration
#

terraform {
  required_version = "~> 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.5.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}