variable "location" {
  description = "Azure Region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Azure resource group"
  type        = string
  default     = "Arc-GKE-Demo"
}

variable "subscriptionId" {
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

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "Arc-GKE-Demo"
}

variable "admin_username" {
  description = "GKE control plane administrator username"
  type        = string
  default     = "arcdemo"
}

variable "admin_password" {
  description = "GKE control plane administrator username"
  type        = string
  sensitive   = true
}

variable "gke_cluster_node_count" {
  description = "GKE cluster node count"
  type        = number
  default     = 1
}

variable "gke_cluster_node_machine_type" {
  description = "GKE cluster node machine type"
  type        = string
  default     = "n1-standard-2"
}