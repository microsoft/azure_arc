# Create an Azure Virtual Network & Subnet
resource "azurerm_network_ddos_protection_plan" "ddos" {
  name                = var.ddos_id
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.name-vnet
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.ddos.id
    enable = true
  }

  tags = var.tags

}

resource "azurerm_subnet" "subnet" {
  name                                           = var.name_subnet_1
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = var.address_space_subnet_1
  service_endpoints                              = []
}

resource "azurerm_subnet" "subnet2" {
  name                                           = var.name_subnet_2
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = var.address_space_subnet_2
  service_endpoints                              = []
}

resource "azurerm_subnet_network_security_group_association" "vnet" {
  for_each                  = var.nsg_ids
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = each.value
}

resource "azurerm_subnet_route_table_association" "vnet" {
  for_each       = var.route_tables_ids
  route_table_id = each.value
  subnet_id      = azurerm_subnet.subnet.id
}
