data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {
}

data "azuread_domains" "aad_domains" {
  only_default = true
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}