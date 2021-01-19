variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_credentials_filename" {
  description = "GCP Project credentials filename"
  type        = string
}

variable "gcp_region" {
  description = "GCP region where resource will be created"
  type        = string
  default     = "us-west1"
}

variable "gcp_zone" {
  description = "GCP zone where resource will be created"
  type        = string
  default     = "us-west1-a"
}

variable "gcp_instance_name" {
  description = "GCP VM instance name"
  type        = string
  default     = "arc-gcp-demo"
}

variable "gcp_instance_machine_type" {
  description = "GCP VM instance type"
  type        = string
  default     = "n2-standard-4"
}

variable "key_name" {
  description = "GCP project key name"
  type        = string
  default     = "rsakey1"
}

variable "location" {
  description = "Azure Region"
  type        = string
  default     = "eastus"
}

variable "resourceGroup" {
  description = "Azure resource group"
  type        = string
  default     = "Arc-GCP-SQL-Demo"
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
}

variable "servicePrincipalTenantId" {
  description = "Azure Tenant ID"
  type        = string
}

variable "admin_user" {
  description = "Guest OS Admin Username"
  type        = string
  default     = "arcdemo" # do not set this to "Administrator"
}

variable "admin_password" {
  description = "Guest OS Admin Password"
  type        = string
}