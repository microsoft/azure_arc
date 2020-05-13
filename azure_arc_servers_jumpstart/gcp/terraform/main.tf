
// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// An Azure Resource Group
resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
 name         = "gcp-vm-${random_id.instance_id.hex}"
 machine_type = "f1-micro"
 zone         = var.gcp_zone

 boot_disk {
   initialize_params {
     image = "ubuntu-os-cloud/ubuntu-1604-lts"
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
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"

    connection {
    type = "ssh"
    host = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
    user = var.admin_username
    private_key = file("~/.ssh/id_rsa")
    timeout = "2m"
    }
 }
 provisioner "file" {
    source      = "scripts/deploy_arcagent.sh"
    destination = "/tmp/deploy_arcagent.sh"

    connection {
    type = "ssh"
    host = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
    user = var.admin_username
    private_key = file("~/.ssh/id_rsa")
    timeout = "2m"
    }
  }
  
  provisioner "remote-exec" {
    inline = [     
           "sudo chmod +x /tmp/deploy_arcagent.sh",
           "/tmp/deploy_arcagent.sh",
          ]

    connection {
    type = "ssh"
    host = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
    user = var.admin_username
    private_key = file("~/.ssh/id_rsa")
    timeout = "2m"
    }
  }
}

resource "local_file" "deploy_arcagent_sh" {
  content = templatefile("scripts/deploy_arcagent.sh.tmpl", {
    resourceGroup                  = var.azure_resource_group
    location                       = var.azure_location
    }
  )
  filename = "scripts/deploy_arcagent.sh"
}

// A variable for extracting the external ip of the instance
output "ip" {
 value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}