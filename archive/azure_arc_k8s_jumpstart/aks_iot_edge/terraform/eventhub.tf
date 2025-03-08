# Create an Azure Event Hub

resource "azurerm_eventhub_namespace" "evhns" {
  name                = var.name-evhns
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = var.sku-evhns
}

resource "azurerm_eventhub" "evh" {
  name                = var.name-evh
  resource_group_name = azurerm_resource_group.rg.name
  namespace_name      = azurerm_eventhub_namespace.evhns.name
  partition_count     = var.partition-count-evh
  message_retention   = var.message-retention-evh
}

resource "azurerm_eventhub_authorization_rule" "evhar" {
  resource_group_name = azurerm_resource_group.rg.name
  namespace_name      = azurerm_eventhub_namespace.evhns.name
  eventhub_name       = azurerm_eventhub.evh.name
  name                = var.name-evhar
  send                = var.send-evhar
}