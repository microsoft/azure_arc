// Configure the AWS provider
provider "aws" {
  version = "2.7.0"
  region  = var.aws_region
}

provider "azurerm" {
  version = "2.9.0"
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

provider "local" {
  version = "1.4"
}