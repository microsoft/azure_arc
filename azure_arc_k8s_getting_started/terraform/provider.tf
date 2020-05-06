# Configure the Microsoft Azure Resource Manager Provider
provider "azurerm" {
  version = "=1.36.1"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}
