variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}
variable "adds_Domain_Name" {
  type        = string
  description = "The FQDN of the domain'"
  default     = "jumpstart.local"
}

variable "adds_VM_Name" {
  type        = string
  description = "The name of your Virtual Machine."
  default     = "ArcBox-ADDS"
}

variable "windows_Admin_Username" {
  type        = string
  description = "Username for the Virtual Machine."
  default     = "arcdemo"
}

variable "windows_Admin_password" {
  type        = string
  description = "Password for the Virtual Machine."
  default     = "ArcPassword123!!"
  sensitive   = true
}

variable "windows_OS_version" {
  type        = string
  description = "The Windows version for the client VM."
  default     = "2022-datacenter-g2"
}

variable "vm_size" {
  type        = string
  description = "The size of the VM."
  default     = "Standard_B2ms"
}

variable "deploy_bastion" {
  type        = bool
  description = "Choice to deploy Bastion to connect to the client VM"
  default     = false
}

variable "template_base_url" {
  type        = string
  description = "Base URL for the GitHub repo where the ArcBox artifacts are located."
}

locals {
  bastion_name            = "ArcBox-Bastion"
  public_ip_name          = var.deploy_bastion == false ? "${var.adds_VM_Name}-PIP" : "${local.bastion_name}-PIP"
  network_interface_name  = "${var.adds_VM_Name}-NIC"
  virtual_network_name    = "ArcBox-VNet"
  dr_virtual_network_name = "ArcBox-DR-VNet"
  dc_subnet_name          = "ArcBox-DC-Subnet"
  adds_private_ip_address = "10.16.2.100"
  os_disk_type            = "Premium_LRS"
}

data "azurerm_subscription" "primary" {
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = local.virtual_network_name
  resource_group_name = var.resource_group_name
}

data "azurerm_virtual_network" "dr_vnet" {
  name                = local.dr_virtual_network_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "subnet" {
  name                 = local.dc_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

resource "azurerm_public_ip" "pip" {
  count               = var.deploy_bastion == false ? 1 : 0
  name                = local.public_ip_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = local.network_interface_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.adds_private_ip_address
    public_ip_address_id          = var.deploy_bastion == false ? azurerm_public_ip.pip[0].id : null
  }
}
resource "azurerm_virtual_machine" "adds" {
  name                  = var.adds_VM_Name
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_OS_version
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.adds_VM_Name}-OS_Disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 1024
  }
  os_profile {
    computer_name  = var.adds_VM_Name
    admin_username = var.windows_Admin_Username
    admin_password = var.windows_Admin_password
  }
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false
  }
}

resource "azurerm_virtual_machine_extension" "custom_script" {
  name                       = var.adds_VM_Name
  virtual_machine_id         = azurerm_virtual_machine.adds.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "fileUris": [
          "${var.template_base_url}artifacts/SetupADDS.ps1"
      ],
      "commandToExecute": "powershell.exe -ExecutionPolicy Bypass -File SetupADDS.ps1 -domainName ${var.adds_Domain_Name} -domainAdminUsername  ${var.windows_Admin_Username} -domainAdminPassword  ${var.windows_Admin_password} -templateBaseUrl ${var.template_base_url}"
    }
SETTINGS
}

resource "azurerm_virtual_network_dns_servers" "update_dns_servers" {
  virtual_network_id = data.azurerm_virtual_network.vnet.id
  dns_servers        = ["10.16.2.100", "168.63.129.16"]
  depends_on = [
    azurerm_virtual_machine_extension.custom_script
  ]
}

resource "azurerm_virtual_network_dns_servers" "update_dns_servers_dr" {
  virtual_network_id = data.azurerm_virtual_network.dr_vnet.id
  dns_servers        = ["10.16.2.100", "168.63.129.16"]
  depends_on = [
    azurerm_virtual_machine_extension.custom_script
  ]
}
