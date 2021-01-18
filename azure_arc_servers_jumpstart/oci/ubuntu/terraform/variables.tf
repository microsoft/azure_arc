# Declare TF variables

variable "azure_location" {
  type = string 
  default = "westus2"
  description = "Sets location of Azure resource group"
}

variable "hostname" {
  type = string 
  default = "Arc-OCI-Demo"
  description = "Sets hostname for the Oracle Virtual Machine"
}

variable "azure_resource_group" {
  type = string
  default = "Arc-OCI-Demo"
  description = "Azure resource group name" 
}

variable "subscription_id" {
  type = string
  description = "Azure subscription ID" 
}

variable "client_id" {
  type = string
  description = "Azure client ID, also known as the Azure service principal ID"  
}

variable "client_secret" {
  type = string
  description = "Azure client secret also known as the Azure service principal password" 
}

variable "tenant_id" {
  type = string
  description = "Azure tenant ID" 
}

variable "tenancy_ocid" {
  type = string
  description = "Oracle tenancy OCID"
}

variable "user_ocid" {
  type = string
  description = "Oracle user OCID"
}

variable "fingerprint" {
  type = string
  description = "Oracle api fingerprint"
}

variable "private_key_path" {
  type = string
  description = "path to private ssh key"
}

variable "compartment_ocid" {
  type = string
  description = # Oracle compartment id
}

variable "region" {
  type = string
  description = "Oracle region" 
}

variable "ssh_public_key" {
  type = string
  description = "public key for Virtual Machine"
}

variable "ad_region_mapping" {
  type = map(string)
  description = "Oracle avalability domain map"
  default = { 
    us-phoenix-1 = 2
    us-ashburn-1 = 1
  }
}

variable "images" {
  type = map(string)
  description = "Oracle Virtual Machine Image, Oracle-provided image "Ubuntu-Linux-18.4-lts"
  default = {
    us-phoenix-1 = "ocid1.image.oc3.us-gov-phoenix-1.aaaaaaaaqhxpqz5jrml5twxtoe7z37fw7qnprlpi4gbx6rgprfwg3vpup2zq"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaah2ms24xr6slrtpppgaipfixozl7utwnf2qwqonb2muk4g43wfzgq"
  }
}
