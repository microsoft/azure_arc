# Create an Azure Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = var.name-log_analytics
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  tags                = var.tags
  retention_in_days   = try(var.retention_in_days, null)
}

resource "azurerm_log_analytics_solution" "solutions" {
  for_each = var.solution_plan_map

  solution_name         = each.key
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.log_analytics.id
  workspace_name        = azurerm_log_analytics_workspace.log_analytics.name

  plan {
    product   = each.value.product
    publisher = each.value.publisher
  }
}