#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    vsphere     = "~> 1.18.1"
    local   = "~> 1.4"
    azurerm = "~> 2.9.0"
  }
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  # If you have a self-signed cert
  allow_unverified_ssl = true
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}
