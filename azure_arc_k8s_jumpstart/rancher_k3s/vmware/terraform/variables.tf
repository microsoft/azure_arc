# Declare Azure variables
variable "location" {
}

variable "resourceGroup" {
  default = "Arc-K3s-Demo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}

# Declare VMware variables
variable "vsphere_user" {
}

variable "vsphere_password" {
}

variable "vsphere_server" {
}

variable "vsphere_datacenter" {
}

variable "vsphere_datastore_cluster" {
  description = "Datastore cluster to deploy the VM."
  default     = ""
}

variable "vsphere_datastore" {
  description = "Datastore to deploy the VM."
  default     = ""
}

variable "vsphere_resource_pool" {
}

variable "network_cards" {
}

variable "ipv4_submask" {
  description = "ipv4 Subnet Mask"
  type        = list(string)
  default     = ["24"]
}

variable "vsphere_folder" {
}

variable "vsphere_vm_template_name" {
}

variable "vsphere_virtual_machine_name" {
  default = "Arc-K3s-Demo"
}

variable "vsphere_virtual_machine_count" {
}

variable "vsphere_virtual_machine_cpu_count" {
}

variable "vsphere_virtual_machine_memory_size" {
}

variable "num_cores_per_socket" {
  description = "The number of cores to distribute among the CPUs in this virtual machine. If specified, the value supplied to num_cpus must be evenly divisible by this value."
  type        = number
  default     = 1
}

variable "cpu_hot_add_enabled" {
  description = "Allow CPUs to be added to this virtual machine while it is running."
  default     = null
}

variable "cpu_hot_remove_enabled" {
  description = "Allow CPUs to be removed to this virtual machine while it is running."
  default     = null
}

variable "memory_hot_add_enabled" {
  description = "Allow memory to be added to this virtual machine while it is running."
  default     = null
}

variable "domain" {
}

variable "virtual_machine_network_address" {
}

variable "virtual_machine_ip_address_start" {
}

variable "vm_gateway" {
  description = "VM gateway to set during provisioning"
  default     = null
}

variable "vm_dns" {
  type    = list(string)
  default = null
}

variable "admin_user" {
}
variable "admin_password" {
}