// An Azure resource group
resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "arc-gcp-demo"
  machine_type = var.instance_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  metadata = {
    ssh-keys = "${var.admin_username}:${file("~/.ssh/id_rsa.pub")}"
  }

  provisioner "file" {
    source      = "scripts/install_arc_agent.sh"
    destination = "/tmp/install_arc_agent.sh"

    connection {
      type        = "ssh"
      host        = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install -y python-ctypes",
      "sudo chmod +x /tmp/install_arc_agent.sh",
      "/tmp/install_arc_agent.sh",
    ]

    connection {
      type        = "ssh"
      host        = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
}

resource "local_file" "install_arc_agent_sh" {
  content = templatefile("scripts/install_arc_agent.sh.tmpl", {
    resourceGroup = var.azure_resource_group
    location      = var.azure_location
    subscriptionId = var.subscription_id
    appId          = var.client_id
    appPassword    = var.client_secret
    tenantId       = var.tenant_id
    }
  )
  filename = "scripts/install_arc_agent.sh"
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
