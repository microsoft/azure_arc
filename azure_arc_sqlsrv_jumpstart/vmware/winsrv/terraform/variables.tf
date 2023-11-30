variable "location" {
  description = "Azure Region"
  type        = string
}

variable "resourceGroup" {
  description = "Azure resource group"
  type        = string
  default     = "Arc-VMware-SQL-Demo"
}

variable "subId" {
  description = "Azure subscription ID"
  type        = string
}

variable "servicePrincipalAppId" {
  description = "Azure service principal App ID"
  type        = string
}

variable "servicePrincipalSecret" {
  description = "Azure service principal App Password"
  type        = string
  sensitive   = true
}

variable "servicePrincipalTenantId" {
  description = "Azure Tenant ID"
  type        = string
}

variable "vsphere_user" {
  description = "VMware vSphere vCenter Username"
  type        = string
}

variable "vsphere_password" {
  description = "VMware vSphere vCenter Password"
  type        = string
}

variable "vsphere_server" {
  description = "VMware vSphere vCenter IP/FQDN"
  type        = string
}

variable "vsphere_datacenter" {
  description = "VMware vSphere Datacenter Name"
  type        = string
}

variable "vsphere_datastore" {
  description = "VMware vSphere Datastore Name"
  type        = string
}

variable "vsphere_resource_pool" {
  description = "VMware vSphere Cluster or Resource Pool Name" // If no Resource Pool is present, use vSphere Cluster <Cluster Name/>
  type        = string
}

variable "network_cards" {
  description = "VMware vSphere Network Name"
  type        = string
}

variable "ipv4_submask" {
  description = "ipv4 Subnet Mask"
  type        = list(string)
  default     = ["24"]
}

variable "vsphere_folder" {
  description = "VMware vSphere Folder Name" // Use the following format for nested folders: "Folder1/Folder2/Folder3"
  type        = string
  sensitive   = true
}

variable "vsphere_vm_template_name" {
  description = "VMware vSphere Virtual Machine Template Name" // Use the following format for nested folders: "Folder1/Template Name"
  type        = string
}

variable "vsphere_virtual_machine_name" {
  description = "VMware vSphere Virtual Machine Name"
  type        = string
}

variable "vsphere_virtual_machine_cpu_count" {
  description = "VMware vSphere Virtual Machine CPU Count"
  type        = number
}

variable "vsphere_virtual_machine_memory_size" {
  description = "VMware vSphere Virtual Machine Memory Size in Megabytes"
  type        = number
}

variable "num_cores_per_socket" {
  description = "The number of cores to distribute among the CPUs in this virtual machine. If specified, the value supplied to num_cpus must be evenly divisible by this value"
  type        = number
  default     = 1
}

variable "admin_user" {
  description = "Guest OS Admin Username"
  type        = string
}

variable "admin_password" {
  description = "Guest OS Admin Password"
  type        = string
  sensitive   = true
}
