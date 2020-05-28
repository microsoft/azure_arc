provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  version        = "~> 1.18.1"
  # If you have a self-signed cert
  allow_unverified_ssl = true
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