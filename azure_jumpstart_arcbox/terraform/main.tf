# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

variable "azure_location" {
  type        = string
  description = "Azure Location"
  default     = "eastus"
}

variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
  default     = "ArcBox-RG"
}

variable "vm_name" {
  type        = string
  description = "The name of the client virtual machine."
  default     = "ArcBox-Client"
}

variable "virtual_network_name" {
  type        = string
  description = "ArcBox vNET name."
  default     = "ArcBox-vNET"
}

variable "subnet_name" {
  type        = string
  description = "ArcBox subnet name."
  default     = "ArcBox-Subnet"
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
  default     = "ArcBox-Workspace"
}

variable "user_ip_address" {
  type        = string
  description = "Users public IP address, used to RDP to the client VM."
}

variable "github_repo" {
  type        = string
  description = "Specify a GitHub repo (used for testing purposes)"
  default     = "microsoft"
}

variable "github_branch" {
  type        = string
  description = "Specify a GitHub branch (used for testing purposes)"
  default     = "main"
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID."
}

variable "spn_client_secret" {
  type        = string
  description = "Arc Service Principal client secret."
}

variable "spn_tenant_id" {
  type        = string
  description = "Arc Service Principal tenantID."
}

### This should be swapped to a lower-case value to avoid case sensitivity ###
variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro'."
  default     = "Full"
}
##############################################################################

locals {
  template_base_url = "https://raw.githubusercontent.com/${var.github_repo}/azure_arc/${var.github_branch}/azure_jumpstart_arcbox/"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.azure_location
}

module "management_storage" {
  source = "./modules/mgmtStorage"

  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

module "management_artifacts" {
  source = "./modules/mgmtArtifacts"

  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = var.virtual_network_name
  subnet_name          = var.subnet_name
  workspace_name       = var.workspace_name

  depends_on = [azurerm_resource_group.rg]
}

module "management_policy" {
  source = "./modules/mgmtPolicy"

  resource_group_name = azurerm_resource_group.rg.name
  workspace_name      = var.workspace_name
  workspace_id        = module.management_artifacts.workspace_id

  depends_on = [azurerm_resource_group.rg, module.management_artifacts]
}

module "client_vm" {
  source = "./modules/clientVm"

  resource_group_name  = azurerm_resource_group.rg.name
  vm_name              = var.vm_name
  virtual_network_name = var.virtual_network_name
  subnet_name          = var.subnet_name
  user_ip_address      = var.user_ip_address
  template_base_url    = local.template_base_url
  storage_account_name = module.management_storage.storage_account_name
  workspace_name       = var.workspace_name
  spn_client_id        = var.spn_client_id
  spn_client_secret    = var.spn_client_secret
  spn_tenant_id        = var.spn_tenant_id
  deployment_flavor    = var.deployment_flavor

  depends_on = [azurerm_resource_group.rg, module.management_storage]
}
