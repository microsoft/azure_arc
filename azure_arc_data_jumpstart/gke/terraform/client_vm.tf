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
    source      = var.gcp_credentials_filename
    destination = "C:/Temp/${var.gcp_credentials_filename}"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "artifacts/azure_arc.ps1"
    destination = "C:/Temp/azure_arc.ps1"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "artifacts/Bootstrap.ps1"
    destination = "C:/Temp/Bootstrap.ps1"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "artifacts/DataServicesLogonScript.ps1"
    destination = "C:/Temp/DataServicesLogonScript.ps1"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "file" {
    source      = "artifacts/local_ssd_sc.yaml"
    destination = "C:/Temp/local_ssd_sc.yaml"

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://Temp/azure_arc.ps1"
    ]

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://Temp/Bootstrap.ps1"
    ]

    connection {
      host     = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      https    = false
      insecure = true
      timeout  = "20m"
      type     = "winrm"
      user     = var.windows_username
      password = var.windows_password
    }
  }

  # Ensure firewall rule is provisioned before server, so that WinRM doesn't fail.
  depends_on = [google_compute_firewall.default]
}

resource "local_file" "password_reset" {
  content = templatefile("artifacts/password_reset.ps1.tmpl", {
    windows_username = var.windows_username
    windows_password = var.windows_password
    }
  )
  filename = "artifacts/password_reset.ps1"
}

resource "local_file" "azure_arc" {
  content = templatefile("artifacts/azure_arc.ps1.tmpl", {
    adminUsername          = var.windows_username
    gcpCredentialsFilename = var.gcp_credentials_filename
    gkeClusterName         = var.gke_cluster_name
    gcpRegion              = var.gcp_region
    spnClientId            = var.SPN_CLIENT_ID
    spnClientSecret        = var.SPN_CLIENT_SECRET
    spnTenantId            = var.SPN_TENANT_ID
    spnAuthority           = var.SPN_AUTHORITY
    AZDATA_USERNAME        = var.AZDATA_USERNAME
    AZDATA_PASSWORD        = var.AZDATA_PASSWORD
    ACCEPT_EULA            = var.ACCEPT_EULA
    arcDcName              = var.ARC_DC_NAME
    subscriptionId         = var.ARC_DC_SUBSCRIPTION
    resourceGroup          = var.ARC_DC_RG
    azureLocation          = var.ARC_DC_REGION
    deploySQLMI            = var.deploy_SQLMI
    deployPostgreSQL       = var.deploy_PostgreSQL
    }
  )
  filename = "artifacts/azure_arc.ps1"
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
