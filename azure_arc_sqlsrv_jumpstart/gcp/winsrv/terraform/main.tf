resource "azurerm_resource_group" "azure_rg" {
  name     = var.resourceGroup
  location = var.location
  tags = {
    project = "jumpstart_azure_arc_sql"
  }
}

resource "google_compute_firewall" "default" {
  name    = "arc-firewall"
  network = google_compute_network.default.name
  allow {
    protocol = "tcp"
    ports    = ["3389", "5985", "5986"]
  }
}

resource "google_compute_network" "default" {
  name = "arc-network"
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = var.gcp_instance_name
  machine_type = var.gcp_instance_machine_type
  zone         = var.gcp_zone
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      # type  = "pd-ssd"
    }
  }
  network_interface {
    network = google_compute_network.default.name

    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  metadata = {
    windows-startup-script-ps1 = local_file.password_reset.content
  }

  provisioner "file" {
    source      = "scripts/install_arc_agent.ps1"
    destination = "C:/tmp/install_arc_agent.ps1"

    connection {
      type     = "winrm"
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/sql.ps1"
    destination = "C:/tmp/sql.ps1"

    connection {
      type     = "winrm"
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/restore_db.ps1"
    destination = "C:/tmp/restore_db.ps1"

    connection {
      type     = "winrm"
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/mma.json"
    destination = "C:/tmp/mma.json"

    connection {
      type     = "winrm"
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp//sql.ps1"
    ]

    connection {
      type     = "winrm"
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  # Ensure firewall rule is provisioned before server, so that WinRM doesn't fail.
  depends_on = [google_compute_firewall.default]
}

resource "local_file" "password_reset" {
  content = templatefile("scripts/password_reset.ps1.tmpl", {
    admin_user     = var.admin_user
    admin_password = var.admin_password
    }
  )
  filename = "scripts/password_reset.ps1"
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

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
