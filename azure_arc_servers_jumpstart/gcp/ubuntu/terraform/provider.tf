#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    google  = "~> 3.21"
    local   = "~> 1.4"
    azurerm = "~> 2.9.0"
  }
}

provider "google" {
  credentials = file(var.gcp_credentials_filename)
  project     = var.gcp_project_id
  region      = var.gcp_region
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}
