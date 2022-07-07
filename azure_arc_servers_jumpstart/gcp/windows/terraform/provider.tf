#
# Providers Configuration
#

terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.8.0"
    }
    google = {
      source = "hashicorp/google"
      version = "4.23.0"
    }
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