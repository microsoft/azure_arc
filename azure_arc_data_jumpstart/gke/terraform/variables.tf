# Declare TF variables
variable "gcp_project_id" {
}

variable "gcp_credentials_filename" {
}

variable "gcp_region" {
  default = "us-west1"
}

variable "gke_cluster_name" {
  default = "arc-data-gke"
}

variable "admin_username" {
  default = "arcadmin"
}

variable "admin_password" {
  default = "arcdemo123!!"
}

variable "gke_cluster_node_count" {
}

variable "gcp_zone" {
  default = "us-west1-a"
}

# variable "key_name" {
#   default = "rsakey1"
# }

variable "windows_username" {
}


variable "windows_password" {
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

variable "DOCKER_USERNAME" {
  description = "Azure Arc Data - Private Preview Docker Registry username"
  type        = string
}

variable "DOCKER_PASSWORD" {
  description = "Azure Arc Data - Private Preview Docker Registry password"
  type        = string
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
  description = "Azure Resource Group where all future Azure Arc resources will be deployed"
  type        = string
}

variable "ARC_DC_REGION" {
  description = "Azure location where the Azure Arc Data Controller resource will be created in Azure (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)"
  type        = string
}

variable "client_id" {
  description = "Your Azure Service Principle name"
  type        = string
}

variable "client_secret" {
  description = "Your Azure Service Principle password"
  type        = string
}

variable "tenant_id" {
  description = "Your Azure tenant ID"
  type        = string
}