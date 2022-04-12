variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "vm_name" {
  type        = string
  description = "The name of the client virtual machine."
}

variable "capi_arc_data_cluster_name" {
  type        = string
  description = "The name of the CAPI cluster"
  default     = "ArcBox-CAPI-Data"
}

variable "k3s_arc_cluster_name" {
  type        = string
  description = "The name of the K3s cluster"
  default     = "ArcBox-K3s"
}

variable "vm_size" {
  type        = string
  description = "The size of the client virtual machine."
  default     = "Standard_D16s_v4"
}

variable "os_sku" {
  type        = string
  description = "The Windows version for the client VM."
  default     = "2022-datacenter-g2"
}

variable "admin_username" {
  type        = string
  description = "Username for the Windows client virtual machine."
}

variable "admin_password" {
  type        = string
  description = "Password for Windows admin account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long."
  sensitive   = true
}

variable "virtual_network_name" {
  type        = string
  description = "ArcBox vNET name."
}

variable "subnet_name" {
  type        = string
  description = "ArcBox subnet name."
}

variable "template_base_url" {
  type        = string
  description = "Base URL for the GitHub repo where the ArcBox artifacts are located."
}

variable "data_controller_username" {
  type        = string
  description = "Arc Data Controller user name."
  default     = "arcdemo"
}

variable "data_controller_password" {
  type        = string
  description = "Arc Data Controller password"
  default     = "ArcPassword123!!"
  sensitive   = true
}

variable "accept_eula" {
  type        = string
  description = "Accept EULA for all ArcBox scripts."
  default     = "yes"
}

variable "storage_account_name" {
  type        = string
  description = "Name for the staging storage account used to hold kubeconfig."
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID."
}

variable "spn_client_secret" {
  type        = string
  description = "Arc Service Principal client secret."
  sensitive   = true
}

variable "spn_tenant_id" {
  type        = string
  description = "Arc Service Principal tenantID."
}

variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro', and 'DevOps'."
}

variable "github_username" {
  type        = string
  description = "Specify a GitHub username for ArcBox DevOps"
  default     = "microsoft"
}

variable "github_repo" {
  type        = string
  description = "Specify a GitHub repo (used for testing purposes)"
}

variable "github_branch" {
  type        = string
  description = "Specify a GitHub branch (used for testing purposes)"
}

variable "trigger_at_logon" {
  type        = bool
  description = "Whether or not the automation scripts will trigger at log on, or at startup. True for AtLogon, False for AtStartup."
  default     = true
}

variable "deploy_bastion" {
  type       = bool
  description = "Choice to deploy Bastion to connect to the client VM"
  default = false
}

### THESE ARE LEGACY VARIABLES FOR BACKWARDS COMPATIBILITY WITH LEGACY SCRIPT FUNCTIONS ###

variable "spn_authority" {
  type        = string
  description = "Authority for Service Principal authentication"
  default     = "https://login.microsoftonline.com"
}

variable "registry_username" {
  type        = string
  description = "Registry username"
  default     = "registryUser"
}

variable "registry_password" {
  type        = string
  description = "Registry password"
  default     = "registrySecret"
}

variable "data_controller_name" {
  type        = string
  description = "Arc Data Controller name."
  default     = "arcdatactrl"
}

variable "sql_mi_name" {
  type        = string
  description = "Arc Data Controller name."
  default     = "arcdatactrl"
}

variable "postgres_name" {
  type        = string
  description = "Name of PostgreSQL server group."
  default     = "arcpg"
}

variable "postgres_worker_node_count" {
  type        = number
  description = "Number of PostgreSQL Hyperscale worker nodes."
  default     = 3
}

variable "postgres_data_size" {
  type        = number
  description = "Size of data volumes in MB."
  default     = 1024
}

variable "postgres_service_type" {
  type        = string
  description = "How PostgreSQL service is accessed through Kubernetes CNI."
  default     = "LoadBalancer"
}
###########################################################################################

locals {
    public_ip_name         = "${var.vm_name}-PIP"
    nsg_name               = "${var.vm_name}-NSG"
    network_interface_name = "${var.vm_name}-NIC"
    bastionSubnetIpPrefix  = "172.16.3.64/26"
}

data "azurerm_subscription" "primary" {
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

resource "azurerm_public_ip" "pip" {
  count               = var.deploy_bastion == false ? 1: 0
  name                = local.public_ip_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "nsg" {
  name                = local.nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "nic" {
  name                = local.network_interface_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.deploy_bastion == false ? azurerm_public_ip.pip[0].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_virtual_machine" "client" {
  name                  = var.vm_name
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [ azurerm_network_interface.nic.id ]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.os_sku
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.vm_name}-OS_Disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 1024
  }
  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false
  }
}

resource "azurerm_virtual_machine_extension" "custom_script" {
  name                       = var.vm_name
  virtual_machine_id         = azurerm_virtual_machine.client.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "fileUris": [
          "${var.template_base_url}artifacts/Bootstrap.ps1"
      ],
      "commandToExecute": "powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${var.admin_username} -spnClientId ${var.spn_client_id} -spnClientSecret ${var.spn_client_secret} -spnTenantId ${var.spn_tenant_id} -spnAuthority ${var.spn_authority} -subscriptionId ${data.azurerm_subscription.primary.subscription_id} -resourceGroup ${data.azurerm_resource_group.rg.name} -azdataUsername ${var.data_controller_username} -azdataPassword ${var.data_controller_password} -acceptEula ${var.accept_eula} -registryUsername ${var.registry_username} -registryPassword ${var.registry_password} -arcDcName ${var.data_controller_name} -azureLocation ${data.azurerm_resource_group.rg.location} -mssqlmiName ${var.sql_mi_name} -POSTGRES_NAME ${var.postgres_name} -POSTGRES_WORKER_NODE_COUNT ${var.postgres_worker_node_count} -POSTGRES_DATASIZE ${var.postgres_data_size} -POSTGRES_SERVICE_TYPE ${var.postgres_service_type} -stagingStorageAccountName ${var.storage_account_name} -workspaceName ${var.workspace_name} -templateBaseUrl ${var.template_base_url} -flavor ${var.deployment_flavor} -automationTriggerAtLogon ${var.trigger_at_logon} -capiArcDataClusterName ${var.capi_arc_data_cluster_name} -k3sArcClusterName ${var.k3s_arc_cluster_name} -githubUser ${var.github_username}"
    }
SETTINGS
}
