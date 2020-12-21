#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    google  = "~> 3.21"
    azurerm = "~> 2.0.0"
  }
}

provider "google" {
  credentials = file(var.gcp_credentials_filename)
  project     = var.gcp_project_id
  region      = var.gcp_region
  # zone        = var.gcp_zone // (Optional) The location (region or zone) in which the cluster master will be created, as well as the default node location. If you specify a zone (such as us-central1-a), the cluster will be a zonal cluster with a single cluster master. If you specify a region (such as us-west1), the cluster will be a regional cluster with multiple masters spread across zones in the region, and with default node locations in those zones as well.
}

provider "azurerm" {
  subscription_id = var.subscriptionId
  client_id       = var.servicePrincipalAppId
  client_secret   = var.servicePrincipalSecret
  tenant_id       = var.servicePrincipalTenantId
  features {}
}