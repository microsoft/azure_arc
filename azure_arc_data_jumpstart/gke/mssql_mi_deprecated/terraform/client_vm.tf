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
    destination = "C:/tmp/${var.gcp_credentials_filename}"

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

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp/azure_arc.ps1"
    ]

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
      "powershell.exe -File C://tmp/ClientTools.ps1"
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
    SPN_CLIENT_ID            = var.SPN_CLIENT_ID
    SPN_CLIENT_SECRET        = var.SPN_CLIENT_SECRET
    SPN_TENANT_ID            = var.SPN_TENANT_ID
    SPN_AUTHORITY            = var.SPN_AUTHORITY
    AZDATA_USERNAME          = var.AZDATA_USERNAME
    AZDATA_PASSWORD          = var.AZDATA_PASSWORD
    ACCEPT_EULA              = var.ACCEPT_EULA
    ARC_DC_NAME              = var.ARC_DC_NAME
    ARC_DC_SUBSCRIPTION      = var.ARC_DC_SUBSCRIPTION
    ARC_DC_RG                = var.ARC_DC_RG
    ARC_DC_REGION            = var.ARC_DC_REGION
    DOCKER_REGISTRY          = var.DOCKER_REGISTRY
    DOCKER_REPOSITORY        = var.DOCKER_REPOSITORY
    DOCKER_TAG               = var.DOCKER_TAG
    adminUsername            = var.adminUsername
    REGISTRY_USERNAME        = var.REGISTRY_USERNAME
    REGISTRY_PASSWORD        = var.REGISTRY_PASSWORD
    MSSQL_MI_NAME            = var.MSSQL_MI_NAME
    }
  )
  filename = "scripts/azure_arc.ps1"
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
