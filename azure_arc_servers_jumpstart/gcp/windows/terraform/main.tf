// Terraform plugin for creating random ids

// An Azure Resource Group
resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "arc-gcp-demo"
  machine_type = "n1-standard-1"
  zone         = var.gcp_zone
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }
  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  metadata = {
    windows-startup-script-ps1 = local_file.install_arc_agent_ps1.content
  }
}

resource "local_file" "install_arc_agent_ps1" {
  content = templatefile("scripts/install_arc_agent.ps1.tmpl", {
    resourceGroup  = var.azure_resource_group
    location       = var.azure_location
    subscriptionId = var.subscription_id
    appId          = var.client_id
    appPassword    = var.client_secret
    tenantId       = var.tenant_id
    }
  )
  filename = "scripts/install_arc_agent.ps1"
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}