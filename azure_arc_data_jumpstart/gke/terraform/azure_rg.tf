resource "azurerm_resource_group" "azure_rg" {
  name     = var.ARC_DC_RG
  location = var.ARC_DC_REGION
}