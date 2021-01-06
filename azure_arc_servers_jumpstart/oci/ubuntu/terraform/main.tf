variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}
variable "ssh_public_key" {}

resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}

variable "ad_region_mapping" {
  type = map(string)
  default = {
    us-phoenix-1 = 2
    us-ashburn-1 = 1
  }
}

variable "images" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Ubuntu-Linux-18.4-lts"
    us-phoenix-1   = "ocid1.image.oc3.us-gov-phoenix-1.aaaaaaaaqhxpqz5jrml5twxtoe7z37fw7qnprlpi4gbx6rgprfwg3vpup2zq"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaah2ms24xr6slrtpppgaipfixozl7utwnf2qwqonb2muk4g43wfzgq"
  }
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = var.ad_region_mapping[var.region]
}

resource "oci_core_virtual_network" "arc_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "ArcVCN"
  dns_label      = "arcvcn"
}

resource "oci_core_subnet" "arc_subnet1" {
  cidr_block        = "10.1.20.0/24"
  display_name      = "ArcSubnet1"
  dns_label         = "arcsubnet1"
  security_list_ids = [oci_core_security_list.arc_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.arc_vcn.id
  route_table_id    = oci_core_route_table.arc_route_table.id
  dhcp_options_id   = oci_core_virtual_network.arc_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "arc_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "arcIG"
  vcn_id         = oci_core_virtual_network.arc_vcn.id
}

resource "oci_core_route_table" "arc_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.arc_vcn.id
  display_name   = "arcRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.arc_internet_gateway.id
  }
}

resource "oci_core_security_list" "arc_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.arc_vcn.id
  display_name   = "arcSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }
}

resource "oci_core_instance" "oci_arc1" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "ociArc1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.arc_subnet1.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "ociarc1"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

connection {
    user        = "ubuntu"
    private_key = file("my_oci_key")
    agent       = false
    host        = oci_core_instance.oci_arc1.public_ip
  }

  provisioner "file" {
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"
  }
  provisioner "file" {
    source      = "scripts/install_arc_agent.sh"
    destination = "/tmp/install_arc_agent.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install -y python-ctypes",
      "sudo chmod +x /tmp/install_arc_agent.sh",
      "/tmp/install_arc_agent.sh",
    ]
  }
}

resource "local_file" "install_arc_agent_sh" {
  content = templatefile("scripts/install_arc_agent.sh.tmpl", {
    resourceGroup = var.azure_resource_group
    location      = var.azure_location
    }
  )
  filename = "scripts/install_arc_agent.sh"
}

data "template_file" "user_data" {
  template = templatefile("scripts/user_data.tmpl", {
    hostname = var.hostname
    }
  )
}

output "your_instance_public_ip" {
  value = oci_core_instance.oci_arc1.*.public_ip
}
