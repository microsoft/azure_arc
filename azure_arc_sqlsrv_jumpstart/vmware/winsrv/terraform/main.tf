resource "azurerm_resource_group" "azure_rg" {
  name     = var.resourceGroup
  location = var.location
  tags = {
    project = "jumpstart_azure_arc_sql"
  }
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_cards
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_vm_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  interface_count     = length(var.ipv4_submask) #Used for Subnet handeling
  template_disk_count = length(data.vsphere_virtual_machine.template.disks)
}

// Provisioning Windows Server from the VM template
resource "vsphere_virtual_machine" "arcdemo" {
  name                   = var.vsphere_virtual_machine_name
  resource_pool_id       = data.vsphere_resource_pool.pool.id
  folder                 = var.vsphere_folder
  datastore_id           = var.vsphere_datastore != "" ? data.vsphere_datastore.datastore.id : null
  num_cpus               = var.vsphere_virtual_machine_cpu_count
  num_cores_per_socket   = var.num_cores_per_socket
  cpu_hot_add_enabled    = true
  cpu_hot_remove_enabled = true
  memory                 = var.vsphere_virtual_machine_memory_size
  memory_hot_add_enabled = true
  guest_id               = data.vsphere_virtual_machine.template.guest_id
  scsi_type              = data.vsphere_virtual_machine.template.scsi_type
  firmware               = "efi"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  // Disks defined in the original template
  dynamic "disk" {
    for_each = data.vsphere_virtual_machine.template.disks
    iterator = template_disks
    content {
      label            = "${var.vsphere_virtual_machine_name}${template_disks.key}"
      size             = data.vsphere_virtual_machine.template.disks[template_disks.key].size
      unit_number      = template_disks.key
      thin_provisioned = data.vsphere_virtual_machine.template.disks[template_disks.key].thin_provisioned
      eagerly_scrub    = data.vsphere_virtual_machine.template.disks[template_disks.key].eagerly_scrub
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      windows_options {
        computer_name    = var.vsphere_virtual_machine_name
        admin_password   = var.admin_password
        run_once_command_list = [
          "net start WinRM",
          "winrm set winrm/config/Service @{AllowUnencrypted='true'}",
          "winrm set winrm/config/Service/Auth @{Basic='true'}",
          "winrm quickconfig -force",
          "winrm set winrm/config @{MaxEnvelopeSizekb=\"100000\"}",
          "winrm set winrm/config/Service @{AllowUnencrypted=\"true\"}",
          "winrm set winrm/config/Service/Auth @{Basic=\"true\"}"]
      }

      network_interface {}
    }
  }

  provisioner "file" {
    source      = "scripts/install_arc_agent.ps1"
    destination = "C:/tmp/install_arc_agent.ps1"

    connection {
      type     = "winrm"
      host     = self.default_ip_address
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "5m"
    }
  }

  provisioner "file" {
    source      = "scripts/sql.ps1"
    destination = "C:/tmp/sql.ps1"

    connection {
      type     = "winrm"
      host     = self.default_ip_address
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "5m"
    }
  }

  provisioner "file" {
    source      = "scripts/restore_db.ps1"
    destination = "C:/tmp/restore_db.ps1"

    connection {
      type     = "winrm"
      host     = self.default_ip_address
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "5m"
    }
  }

  provisioner "file" {
    source      = "scripts/mma.json"
    destination = "C:/tmp/mma.json"

    connection {
      type     = "winrm"
      host     = self.default_ip_address
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp//sql.ps1"
    ]

    connection {
      type     = "winrm"
      host     = self.default_ip_address
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "5m"
    }
  }
}

resource "local_file" "sql_ps1" {
  content = templatefile("scripts/sql.ps1.tmpl", {
    admin_user               = var.admin_user
    admin_password           = var.admin_password
    resourceGroup            = var.resourceGroup
    location                 = var.location
    servicePrincipalAppId    = var.servicePrincipalAppId
    servicePrincipalSecret   = var.servicePrincipalSecret
    servicePrincipalTenantId = var.servicePrincipalTenantId
    }
  )
  filename = "scripts/sql.ps1"
}

resource "local_file" "install_arc_agent_ps1" {
  content = templatefile("scripts/install_arc_agent.ps1.tmpl", {
    resourceGroup            = var.resourceGroup
    location                 = var.location
    subId                    = var.subId
    servicePrincipalAppId    = var.servicePrincipalAppId
    servicePrincipalSecret   = var.servicePrincipalSecret
    servicePrincipalTenantId = var.servicePrincipalTenantId
    }
  )
  filename = "scripts/install_arc_agent.ps1"
}

output "vm_ip" {
  value = "${vsphere_virtual_machine.arcdemo.*.default_ip_address}"
}
