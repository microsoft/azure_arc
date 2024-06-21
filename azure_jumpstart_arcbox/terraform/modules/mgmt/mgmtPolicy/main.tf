variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "workspace_id" {
  type        = string
  description = "Log Analytics workspace id."
}

variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro', and 'DevOps'."
}

locals {
  policies = [
      {
          name   = "(ArcBox) Enable Azure Monitor for Hybrid VMs with AMA"
          id     = "/providers/Microsoft.Authorization/policySetDefinitions/59e9c3eb-d8df-473b-8059-23fd38ddd0f0"
          params = { "logAnalyticsWorkspace": { "value": "${var.workspace_id}" }}
          role   = [ "Log Analytics Contributor", "Azure Connected Machine Resource Administrator", "Monitoring Contributor" ]
          flavor = ["ITPro" ]
      },
      {
          name   = "(ArcBox) Tag resources"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26"
          params = { "tagName": { "value": "project" }, "tagValue": { "value": "jumpstart_arcbox" }}
          role   = "Tag Contributor"
          flavor = [ "DevOps", "ITPro" , "DataOps" ]
      },
      {
          name   = "(ArcBox) Enable Azure Defender on Kubernetes clusters"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c"
          params = {}
          role   = "Log Analytics Contributor"
          flavor = [ "DevOps" ]
      }
  ]
}

data "azurerm_subscription" "primary" {
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_resource_group_policy_assignment" "policies" {
  for_each             = { for i, v in local.policies: i => v 
                           if contains(v.flavor, var.deployment_flavor)
                         }
  name                 = each.value.name
  location             = data.azurerm_resource_group.rg.location
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = each.value.id
  identity {
      type = "SystemAssigned"
  }
  parameters = <<PARAMETERS
${jsonencode(each.value.params)}
PARAMETERS
}

resource "azurerm_role_assignment" "policy_AMA_role_0" {
  count                = contains(local.policies[0].flavor, var.deployment_flavor) ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = local.policies[0].role[0]
  principal_id         = azurerm_resource_group_policy_assignment.policies[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "policy_AMA_role_1" {
  count                = contains(local.policies[0].flavor, var.deployment_flavor) ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = local.policies[0].role[1]
  principal_id         = azurerm_resource_group_policy_assignment.policies[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "policy_AMA_role_2" {
  count                = contains(local.policies[0].flavor, var.deployment_flavor) ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = local.policies[0].role[2]
  principal_id         = azurerm_resource_group_policy_assignment.policies[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "policy_tagging_resources" {
  count                = contains(local.policies[1].flavor, var.deployment_flavor) ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = local.policies[1].role
  principal_id         = azurerm_resource_group_policy_assignment.policies[1].identity[0].principal_id
}

resource "azurerm_role_assignment" "policy_defender_kubernetes" {
  count                = contains(local.policies[2].flavor, var.deployment_flavor) ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = local.policies[2].role
  principal_id         = azurerm_resource_group_policy_assignment.policies[2].identity[0].principal_id
}