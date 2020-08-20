#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    aws     = "~> 2.7.0"
    local   = "~> 1.4"
    http    = "~> 1.2.0"
    azurerm = "~> 2.9.0"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}
