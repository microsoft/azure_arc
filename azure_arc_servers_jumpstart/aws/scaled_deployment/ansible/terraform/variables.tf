# Declare TF variables
variable "server_count" {
  default = 4
}

variable "aws_region" {
  default = "us-west-2"
}
variable "aws_availabilityzone" {
  default = "us-west-2a"
}

variable "admin_username" {
  default = "arcadmin"
}

variable "admin_password" {
  default = "arcdemo123!!"
}

variable "azure_location" {
  default = "westus2"
}

variable "hostname" {
  default = "aws-server"
}

variable "azure_resource_group" {
  default = "Arc-AWS-Demo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}
