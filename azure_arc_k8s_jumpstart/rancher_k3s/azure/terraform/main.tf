resource "azurerm_resource_group" "arck3sdemo" {
  name     = var.azure_resource_group
  location = var.location
}

resource "azurerm_virtual_network" "arck3sdemo" {
  name                = "${var.azure_vnet}-VNET"
  address_space       = ["${var.azure_vnet_address_space}"]
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name
}

resource "azurerm_subnet" "arck3sdemo" {
  name                 = var.azure_vnet_subnet
  resource_group_name  = azurerm_resource_group.arck3sdemo.name
  virtual_network_name = azurerm_virtual_network.arck3sdemo.name
  address_prefix       = var.azure_subnet_address_prefix
}

resource "azurerm_public_ip" "arck3sdemo" {
  name                = "${var.azure_public_ip}-PIP"
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "arck3sdemo" {
  name                = "${var.azure_nsg}-NSG"
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
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_k8s_6443"
    description                = "Allow k8s ports access"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_k8s_80"
    description                = "Allow k8s ports access"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_k8s_8080"
    description                = "Allow k8s ports access"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_k8s_443"
    description                = "Allow k8s ports access"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_k8s_kubelet"
    description                = "Allow k8s ports access"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_traefik_lb_external"
    description                = "Allow Traefik LoadBalancer external port access"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "32323"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface" "arck3sdemo" {
  name                = "${var.azure_vm_nic}-NIC"
  location            = azurerm_resource_group.arck3sdemo.location
  resource_group_name = azurerm_resource_group.arck3sdemo.name

  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.arck3sdemo.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.arck3sdemo.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.arck3sdemo.id
  network_security_group_id = azurerm_network_security_group.arck3sdemo.id
}

resource "azurerm_linux_virtual_machine" "arck3sdemo" {
  name                            = var.azure_vm_name
  resource_group_name             = azurerm_resource_group.arck3sdemo.name
  location                        = azurerm_resource_group.arck3sdemo.location
  size                            = var.azure_vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.arck3sdemo.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.azure_vm_name}-OS-Disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.azure_vm_os_disk_size_gb
  }

  tags = {
    Project = "jumpstart_azure_arc_k8s"
  }

  provisioner "file" {
    source      = "scripts/install_k3s.sh"
    destination = "/tmp/install_k3s.sh"

    connection {
      type     = "ssh"
      host     = azurerm_public_ip.arck3sdemo.ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "2m"
    }
  }

  provisioner "file" {
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"

    connection {
      type     = "ssh"
      host     = azurerm_public_ip.arck3sdemo.ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "2m"
    }
  }

  provisioner "file" {
    source      = "deployment/hello-kubernetes.yaml"
    destination = "hello-kubernetes.yaml"

    connection {
      type     = "ssh"
      host     = azurerm_public_ip.arck3sdemo.ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "2m"
    }
  }

  provisioner "remote-exec" {

    inline = [
      "sudo chmod +x /tmp/install_k3s.sh",
      "/tmp/install_k3s.sh",
    ]

    connection {
      type     = "ssh"
      host     = azurerm_public_ip.arck3sdemo.ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "2m"
    }
  }
}

# Output VM Public IP
data "azurerm_public_ip" "arck3sdemo" {
  name                = azurerm_public_ip.arck3sdemo.name
  resource_group_name = azurerm_linux_virtual_machine.arck3sdemo.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.arck3sdemo.ip_address
}