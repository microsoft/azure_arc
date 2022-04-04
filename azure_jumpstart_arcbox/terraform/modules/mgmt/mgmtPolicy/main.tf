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
          name   = "(ArcBox) Deploy Linux Log Analytics agents"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/9d2b61b4-1d14-4a63-be30-d4498e7ad2cf"
          params = { "logAnalytics": { "value": "${var.workspace_id}" }}
          role   = "Log Analytics Contributor"
          flavor = [ "Full", "ITPro" ]
      },
      {
          name   = "(ArcBox) Deploy Windows Log Analytics agents"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/69af7d4a-7b18-4044-93a9-2651498ef203"
          params = { "logAnalytics": { "value": "${var.workspace_id}" }}
          role   = "Log Analytics Contributor"
          flavor = [ "Full", "ITPro" ]
      },
      {
          name   = "(ArcBox) Deploy Linux Dependency Agents"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43"
          params = {}
          role   = "Log Analytics Contributor"
          flavor = [ "Full", "ITPro" ]
      },
      {
          name   = "(ArcBox) Deploy Windows Dependency Agents"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4"
          params = {}
          role   = "Log Analytics Contributor"
          flavor = [ "Full", "ITPro" ]
      },
      {
          name   = "(ArcBox) Enable Azure Defender on Kubernetes clusters"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c"
          params = {}
          role   = "Log Analytics Contributor"
          flavor = [ "Full" ]
      },
      {
          name   = "(ArcBox) Tag resources"
          id     = "/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26"
          params = { "tagName": { "value": "project" }, "tagValue": { "value": "jumpstart_arcbox" }}
          role   = "Tag Contributor"
          flavor = [ "Full", "DevOps" ]
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

resource "azurerm_role_assignment" "roles" {
  for_each             = { for i, v in local.policies: i => v 
                           if contains(v.flavor, var.deployment_flavor)
                         }
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = each.value.role
  principal_id         = azurerm_resource_group_policy_assignment.policies[index(local.policies, each.value)].identity[0]["principal_id"]
}
