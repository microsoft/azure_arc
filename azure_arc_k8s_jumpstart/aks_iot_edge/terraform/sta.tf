# Create an Azure Storage Account

resource "azurerm_storage_account" "sta" {
  name                      = var.name-sta
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  account_tier              = var.sku-sta
  account_replication_type  = var.replication-type-sta
  enable_https_traffic_only = var.http-traffic-only-sta
}

resource "azurerm_storage_container" "sta_container" {
  name                  = var.name-sta-container
  storage_account_name  = azurerm_storage_account.sta.name
  container_access_type = var.access-type-sta-container
}