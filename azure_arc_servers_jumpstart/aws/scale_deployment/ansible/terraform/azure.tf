resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}
