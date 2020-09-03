#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    aws     = "~> 3.4"
    local   = "~> 1.4"
    http    = "~> 1.2.0"
    azurerm = "~> 2.25.0"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

# # Using these data sources allows the configuration to be generic for any region.
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

provider "azurerm" {
  subscription_id = var.ARC_DC_SUBSCRIPTION
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  features {}
}