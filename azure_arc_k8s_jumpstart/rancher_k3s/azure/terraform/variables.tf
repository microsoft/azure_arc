# Declare Azure variables

variable "azure_vm_name" {
  type        = string
  description = "The name of you Virtual Machine."
  default     = "Arc-K3s-Demo"
}

variable "admin_username" {
  type        = string
  description = "Username for the Virtual Machine."
  default     = "arcdemo"
}

variable "ssh_rsa_public_key" {
  type        = string
  description = "SSH Key for the Virtual Machine. SSH key is recommended over password."
  sensitive   = true
}

variable "client_id" {
  type        = string
  description = "Unique SPN app ID."
}
variable "client_secret" {
  type        = string
  description = "Unique SPN password."
  sensitive   = true
}

variable "tenant_id" {
  type        = string
  description = "Unique SPN tenant ID"
}

variable "ubuntuOSVersion" {
  type        = string
  description = "The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version."
  default     = "22_04-lts-gen2"
}

variable "location" {
  type        = string
  description = "Location for all resources."
}

variable "azure_vm_size" {
  type        = string
  description = "The size of the VM."
  default     = "Standard_D4s_v4"
}

variable "github_account" {
  type        = string
  description = "Target GitHub account."
  default     = "microsoft"
}

variable "github_branch" {
  type        = string
  description = "Target GitHub branch."
  default     = "main"
}

variable "deploy_bastion" {
  type        = bool
  description = "Choice to deploy Bastion to connect to the Ubuntu VM."
  default     = false
}

variable "bastion_subnet_prefix" {
  type        = string
  description = "Azure Bastion subnet IP prefix."
  default     = "172.16.2.64/26"
}

variable "azure_resource_group" {
  type        = string
  description = "Resource Group name."
}

variable "azure_vnet_address_space" {
  type        = string
  description = "Address prefix of the virtual network."
  default     = "172.16.0.0/16"
}

variable "azure_vnet_subnet" {
  type        = string
  description = "Name of the subnet in the virtual network."
  default     = "subnet"
}

variable "azure_subnet_address_prefix" {
  type        = string
  description = "Address prefix of the subnet in the virtual network."
  default     = "172.16.1.0/24"
}

variable "azure_vm_os_disk_size_gb" {
  type        = string
  description = "The Size of the Internal OS Disk in GB."
  default     = "32"
}
