# Declare TF variables
variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_credentials_filename" {
  description = "GCP Credentials filename (JSON)"
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

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "arc-data-gke"
}

variable "admin_username" {
  description = "GKE cluster administrator username"
  type        = string
  default     = "arcadmin"
}

variable "admin_password" {
  description = "GKE cluster administrator password"
  type        = string
  default     = "ArcDemo1234567!!"
}

variable "gke_cluster_node_count" {
  description = "GKE cluster number of worker nodes"
  type        = number
}

variable "windows_username" {
  description = "Windows Server Client compute instance VM administrator username"
  type        = string
  default     = "arcdemo"
}

variable "windows_password" {
  description = "Windows Server Client compute instance VM administrator password"
  type        = string
  default     = "Passw0rd123!!"
}

variable "AZDATA_USERNAME" {
  description = "Azure Arc Data Controller admin username"
  type        = string
}

variable "AZDATA_PASSWORD" {
  description = "Azure Arc Data Controller admin password (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols.)"
  type        = string
}

variable "ACCEPT_EULA" {
  description = "Azure Arc EULA acceptance (DO NOT CHANGE)"
  type        = string
  default     = "yes"
}

variable "ARC_DC_NAME" {
  description = "Azure Arc Data Controller name. The name must consist of lowercase alphanumeric characters or '-', and must start and end with a alphanumeric character (This name will be used for k8s namespace as well)."
  type        = string
}

variable "ARC_DC_SUBSCRIPTION" {
  description = "Azure Arc Data Controller Azure subscription ID"
  type        = string
}

variable "ARC_DC_RG" {
  description = "Azure resource group where all future Azure Arc resources will be deployed"
  type        = string
}

variable "ARC_DC_REGION" {
  description = "Azure location where the Azure Arc Data Controller resource will be created in Azure (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)"
  type        = string
}

variable "SPN_CLIENT_ID" {
  description = "Your Azure service principal name"
  type        = string
}

variable "SPN_CLIENT_SECRET" {
  description = "Your Azure service principal password"
  type        = string
}

variable "SPN_TENANT_ID" {
  description = "Your Azure tenant ID"
  type        = string
}

variable "SPN_AUTHORITY" {
  description = "The Service Principal authority"
  type        = string
}

variable "deploy_SQLMI" {
  description = "The Service Principal authority"
  type        = bool
  default     = false
}

variable "deploy_PostgreSQL" {
  description = "The Service Principal authority"
  type        = bool
  default     = false
}