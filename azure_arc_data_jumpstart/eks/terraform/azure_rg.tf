resource "azurerm_resource_group" "arc-data-demo" {
  name     = var.ARC_DC_RG
  location = var.ARC_DC_REGION
}