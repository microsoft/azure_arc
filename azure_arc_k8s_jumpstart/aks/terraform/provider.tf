#
# Providers Configuration
#

terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.8.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}