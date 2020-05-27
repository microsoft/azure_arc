// Configure the Google Cloud provider
provider "google" {
  version     = "3.21"
  credentials = file(var.gcp_credentials_filename)
  project     = var.gcp_project_id
  region      = var.gcp_region
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