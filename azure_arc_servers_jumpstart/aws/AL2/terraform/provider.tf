#
# Providers Configuration
#

terraform {
  required_version = ">= 1.3.5"
  required_providers {
    aws     = ">= 4.42.0"
    local   = ">= 2.2.3"
    http    = ">= 3.2.1"
    azurerm = ">= 3.33.0"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}