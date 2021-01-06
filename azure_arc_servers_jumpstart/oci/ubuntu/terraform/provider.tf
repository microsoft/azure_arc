#
# Providers Configuration
#

terraform {
  required_version = "~> 0.12"
  required_providers {
    oci     = "~> 3.27"
    local   = "~> 1.4"
    http    = "~> 1.2.0"
    azurerm = "~> 2.9.0"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}
