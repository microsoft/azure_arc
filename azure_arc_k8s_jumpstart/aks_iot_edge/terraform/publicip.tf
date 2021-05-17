# Create an Azure Virtual Machine

resource "azurerm_public_ip" "publicip" {
    name                         = var.name-publicip
    location                     = var.location
    resource_group_name          = azurerm_resource_group.rg.name
    allocation_method            = var.allocation-method-publicip

}