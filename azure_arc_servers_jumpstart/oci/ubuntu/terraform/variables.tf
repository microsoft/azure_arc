# Declare TF variables

variable "azure_location" {
}

variable "hostname" {
  default = "Arc-OCI-Demo"
}

variable "azure_resource_group" {
  default = "Arc-OCI-Demo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}

variable "tenancy_ocid" {
}

variable "user_ocid" {
}

variable "fingerprint" {
}

variable "private_key_path" {
}

variable "compartment_ocid" {
}

variable "region" {
}

variable "ssh_public_key" {
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
    us-phoenix-1 = "ocid1.image.oc3.us-gov-phoenix-1.aaaaaaaaqhxpqz5jrml5twxtoe7z37fw7qnprlpi4gbx6rgprfwg3vpup2zq"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaah2ms24xr6slrtpppgaipfixozl7utwnf2qwqonb2muk4g43wfzgq"
  }
}




