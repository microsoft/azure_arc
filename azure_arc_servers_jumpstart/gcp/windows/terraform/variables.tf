# Declare TF variables
variable "gcp_project_id" {
}

variable "gcp_credentials_filename" {
}

variable "gcp_region" {
  default = "us-west1"
}

variable "gcp_zone" {
  default = "us-west1-a"
}

variable "admin_username" {
  default = "arcdemo"
}

variable "admin_password" {
  default = "arcPassword123!!"
  sensitive = true
}
variable "instance_type" {
  default = "n1-standard-1"
}
variable "key_name" {
  default = "rsakey1"
}

variable "azure_location" {
  default = "westus2"
}

variable "azure_resource_group" {
  default = "Arc-GCP-Demo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
  sensitive = true
}

variable "tenant_id" {
}
