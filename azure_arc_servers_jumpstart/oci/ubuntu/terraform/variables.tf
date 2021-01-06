# Declare TF variables

variable "azure_location" {
  default = "westus2"
}

variable "hostname" {
  default = "arc-OCI-demo"
}

variable "azure_resource_group" {
  default = "Arc-OCI-Demo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}
