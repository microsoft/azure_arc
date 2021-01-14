# Declare TF variables

# Sets location of Azure resource group
variable "azure_location" {
  type = string 
  default = "westus2"
}

# Sets hostname for the Oracle Virtual Machine
variable "hostname" {
  type = string 
  default = "Arc-OCI-Demo"
}

# name of Azure resource group
variable "azure_resource_group" {
  type = string
  default = "Arc-OCI-Demo"
}

# Azure subscription ID
variable "subscription_id" {
  type = string
}

# Azure client ID, also known as the Azure service principal ID
variable "client_id" {
  type = string
}

# Azure client secret also known as the Azure service principal password
variable "client_secret" {
  type = string
}

# Azure tenant ID 
variable "tenant_id" {
  type = string
}

# Oracle tenancy OCID
variable "tenancy_ocid" {
  type = string
}

# Oracle user OCID
variable "user_ocid" {
  type = string
}

# Oracle api fingerprint
variable "fingerprint" {
  type = string
}

# path to private ssh key
variable "private_key_path" {
  type = string
}

# Oracle compartment id
variable "compartment_ocid" {
  type = string
}

# Oracle region 
variable "region" {
  type = string
}

# public key for Virtual Machine 
variable "ssh_public_key" {
  type = string
}

# Oracle avalability domain map
variable "ad_region_mapping" {
  type = map(string)
  default = {
    us-phoenix-1 = 2
    us-ashburn-1 = 1
  }
}

# Oracle Virtual Machine Image
# See https://docs.us-phoenix-1.oraclecloud.com/images/
# Oracle-provided image "Ubuntu-Linux-18.4-lts"
variable "images" {
  type = map(string)
  default = {
    us-phoenix-1 = "ocid1.image.oc3.us-gov-phoenix-1.aaaaaaaaqhxpqz5jrml5twxtoe7z37fw7qnprlpi4gbx6rgprfwg3vpup2zq"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaah2ms24xr6slrtpppgaipfixozl7utwnf2qwqonb2muk4g43wfzgq"
  }
}
