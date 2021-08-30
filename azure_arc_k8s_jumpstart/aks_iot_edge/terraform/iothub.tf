# Create an Azure IoT Hub
resource "azurerm_iothub" "iot" {
  name                = var.name-iot
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  sku {
    name     = var.sku-iot
    capacity = var.sku-capacity-iot
  }

  endpoint {
    type                       = var.endpoint-type-iot
    connection_string          = azurerm_storage_account.sta.primary_blob_connection_string
    name                       = var.endpoint-name-iot
    batch_frequency_in_seconds = var.endpoint-batch-frequency-iot
    max_chunk_size_in_bytes    = var.endpoint-chunk-iot
    container_name             = azurerm_storage_container.sta_container.name
    encoding                   = var.endpoint-encoding-iot
    file_name_format           = var.endpoint-file-name-format-iot
  }

  route {
    name           = var.route-name-iot
    source         = var.route-source-iot
    condition      = var.route-condition-iot
    endpoint_names = var.route-endpoint-names-iot
    enabled        = var.route-enabled-names-iot
  }
  
  tags = var.tags
  
}