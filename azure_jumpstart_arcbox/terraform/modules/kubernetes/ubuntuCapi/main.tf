variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "vm_name" {
  type        = string
  description = "The name of the capi virtual machine"
}

variable "capi_arc_data_cluster_name" {
  type        = string
  description = "The name of the capi virtual machine"
  default     = "ArcBox-CAPI-Data"
}

variable "vm_size" {
  type        = string
  description = "The size of the capi virtual machine"
  default     = "Standard_B4ms"
}

variable "os_sku" {
  type        = string
  description = "The Linux version for the capi VM"
  default     = "20_04-lts-gen2"
  ### Add limit list, currently only 20.04-LTS ###
}

variable "admin_username" {
  type        = string
  description = "Username for the Linux capi virtual machine"
}

variable "admin_ssh_key" {
  type        = string
  description = "SSH Key for the Linux VM's"
}

variable "virtual_network_name" {
  type        = string
  description = "ArcBox VNET name"
}

variable "subnet_name" {
  type        = string
  description = "ArcBox subnet name"
}

variable "template_base_url" {
  type        = string
  description = "Base URL for the GitHub repo where the ArcBox artifacts are located"
}

variable "storage_account_name" {
  type        = string
  description = "Name for the staging storage account used to hold kubeconfig"
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID"
}

variable "spn_client_secret" {
  type        = string
  description = "Arc Service Principal client secret"
}

variable "spn_tenant_id" {
  type        = string
  description = "Arc Service Principal tenantID"
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name"
}

variable "deploy_bastion" {
  type       = bool
  description = "Choice to deploy Bastion to connect to the client VM"
  default = false
}

variable "deployment_flavor" {
  type        = string
  description = "The flavor of ArcBox you want to deploy. Valid values are: 'Full', 'ITPro', 'DevOps' and 'DataOps'."
}

locals {
    public_ip_name         = "${var.vm_name}-PIP"
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
  name                = local.public_ip_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  count               = var.deploy_bastion == false ? 1: 0
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
resource "azurerm_virtual_machine" "client" {
  name                  = var.vm_name
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [ azurerm_network_interface.nic.id ]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = var.os_sku
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.vm_name}-OS_Disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = "ArcPassword123!!" ### TEMPORARY ###
  }

  os_profile_linux_config {
      ssh_keys {
        key_data = file(var.admin_ssh_key)
        path = "/home/${var.admin_username}/.ssh/authorized_keys"
      }
      disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "custom_script" {
  name                       = var.vm_name
  virtual_machine_id         = azurerm_virtual_machine.client.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  timeouts {
    create = "60m"
  }

  protected_settings = <<PROTECTED_SETTINGS
    {
      "fileUris": [
          "${var.template_base_url}artifacts/installCAPI.sh"
      ],
      "commandToExecute": "bash installCAPI.sh ${var.admin_username} ${var.spn_client_id} ${var.spn_client_secret} ${var.spn_tenant_id} ${var.vm_name} ${data.azurerm_resource_group.rg.location} ${var.storage_account_name} ${var.workspace_name} ${var.capi_arc_data_cluster_name} ${var.template_base_url} ${var.deployment_flavor}"
    }
PROTECTED_SETTINGS
}
