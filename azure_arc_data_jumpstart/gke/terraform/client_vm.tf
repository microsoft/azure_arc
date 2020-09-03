resource "google_compute_firewall" "default" {
  name    = "arc-firewall"
  network = google_compute_network.default.name
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["3389", "5985", "5986"]
  }

  target_tags = ["arc"]

  depends_on = [google_container_cluster.arcdemo]
}

resource "google_compute_network" "default" {
  name = "arc-network"
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "arc-gcp-demo"
  machine_type = "n1-standard-2"
  tags         = ["arc"]
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
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
    source      = "account.json"
    destination = "C:/tmp/account.json"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "10m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "scripts/azure_arc.ps1"
    destination = "C:/tmp/azure_arc.ps1"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "10m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "scripts/ClientTools.ps1"
    destination = "C:/tmp/ClientTools.ps1"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "10m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "scripts/local_ssd_sc.yaml"
    destination = "C:/tmp/local_ssd_sc.yaml"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "10m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp/azure_arc.ps1"
    ]

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp/ClientTools.ps1"
    ]

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  # Ensure firewall rule is provisioned before server, so that WinRM doesn't fail.
  depends_on = [google_compute_firewall.default]
}

resource "local_file" "password_reset" {
  content = templatefile("scripts/password_reset.ps1.tmpl", {
    windows_username = var.windows_username
    windows_password = var.windows_password
    }
  )
  filename = "scripts/password_reset.ps1"
}

resource "local_file" "azure_arc" {
  content = templatefile("scripts/azure_arc.ps1.tmpl", {
    gcp_credentials_filename = var.gcp_credentials_filename
    gke_cluster_name         = var.gke_cluster_name
    gcp_region               = var.gcp_region
    client_id                = var.client_id
    client_secret            = var.client_secret
    tenant_id                = var.tenant_id
    AZDATA_USERNAME          = var.AZDATA_USERNAME
    AZDATA_PASSWORD          = var.AZDATA_PASSWORD
    ACCEPT_EULA              = var.ACCEPT_EULA
    REGISTRY_USERNAME        = var.REGISTRY_USERNAME
    REGISTRY_PASSWORD        = var.REGISTRY_PASSWORD
    ARC_DC_NAME              = var.ARC_DC_NAME
    ARC_DC_SUBSCRIPTION      = var.ARC_DC_SUBSCRIPTION
    ARC_DC_RG                = var.ARC_DC_RG
    ARC_DC_REGION            = var.ARC_DC_REGION
    }
  )
  filename = "scripts/azure_arc.ps1"
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
