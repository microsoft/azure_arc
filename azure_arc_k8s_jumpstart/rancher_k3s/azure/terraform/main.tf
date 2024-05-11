locals {
  template_base_url           = "https://raw.githubusercontent.com/${var.github_account}/azure_arc/${var.github_branch}/azure_arc_k8s_jumpstart/rancher_k3s/azure/terraform/"
  vm_name                     = "${var.azure_vm_name}-${random_string.guid.result}"
  virtual_network_name        = "${var.azure_vm_name}-VNET-${random_string.guid.result}"
  public_ip_name              = "${var.azure_vm_name}-PIP-${random_string.guid.result}"
  network_security_group_name = "${var.azure_vm_name}-NSG-${random_string.guid.result}"
  network_interface_name      = "${var.azure_vm_name}-NIC-${random_string.guid.result}"
  os_disk_name                = "${var.azure_vm_name}-OSDisk-${random_string.guid.result}"
}

resource "random_string" "guid" {
  length  = 4
  special = false
}

resource "azurerm_resource_group" "arck3sdemo" {
  name     = var.azure_resource_group
  location = var.location
}

resource "azurerm_virtual_network" "arck3sdemo" {
  name                = local.virtual_network_name
  address_space       = ["${var.azure_vnet_address_space}"]
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name
}

resource "azurerm_subnet" "arck3sdemo" {
  name                 = var.azure_vnet_subnet
  resource_group_name  = azurerm_resource_group.arck3sdemo.name
  virtual_network_name = azurerm_virtual_network.arck3sdemo.name
  address_prefixes     = [var.azure_subnet_address_prefix]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.arck3sdemo.name
  virtual_network_name = azurerm_virtual_network.arck3sdemo.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_public_ip" "arck3sdemo" {
  count               = var.deploy_bastion == false ? 1 : 0
  name                = local.public_ip_name
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "arck3sdemo" {
  name                = local.network_security_group_name
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow Remote Desktop access"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bastion_subnet_prefix
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface" "arck3sdemo" {
  name                = local.network_interface_name
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name

  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.arck3sdemo.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.deploy_bastion == false ? azurerm_public_ip.arck3sdemo[0].id : null
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.arck3sdemo.id
  network_security_group_id = azurerm_network_security_group.arck3sdemo.id
}

resource "azurerm_linux_virtual_machine" "arck3sdemo" {
  name                            = local.vm_name
  resource_group_name             = azurerm_resource_group.arck3sdemo.name
  location                        = azurerm_resource_group.arck3sdemo.location
  size                            = var.azure_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.arck3sdemo.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_rsa_public_key
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = var.ubuntuOSVersion
    version   = "latest"
  }

  os_disk {
    name                 = local.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.azure_vm_os_disk_size_gb
  }

  tags = {
    Project = "jumpstart_azure_arc_k8s"
  }

}

resource "azurerm_virtual_machine_extension" "custom_script" {
  name                       = var.azure_vm_name
  virtual_machine_id         = azurerm_linux_virtual_machine.arck3sdemo.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  timeouts {
    create = "60m"
  }

  protected_settings = <<PROTECTED_SETTINGS
    {
      "fileUris": [
          "${local.template_base_url}scripts/installK3s.sh"
      ],
  "commandToExecute": "bash installK3s.sh ${var.admin_username} ${var.client_id} ${var.client_secret} ${var.tenant_id} ${local.vm_name} ${azurerm_resource_group.arck3sdemo.location} ${local.template_base_url} ${var.object_id} ${var.azure_resource_group}"    }
PROTECTED_SETTINGS
}

# Output 
output "admin_username" {
  value = var.admin_username
}

output "ssh_command" {
  value = var.deploy_bastion ? null : "ssh ${var.admin_username}@${azurerm_public_ip.arck3sdemo[0].ip_address}"
}