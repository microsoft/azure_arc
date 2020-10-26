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
  zone        = var.gcp_zone
}

provider "azurerm" {
  features {}
  subscription_id = var.subId
  client_id       = var.servicePrincipalAppId
  client_secret   = var.servicePrincipalSecret
  tenant_id       = var.servicePrincipalTenantId
}