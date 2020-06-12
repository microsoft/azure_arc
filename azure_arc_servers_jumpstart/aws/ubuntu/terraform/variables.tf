# Declare TF variables
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
  default = "arc-aws-demo"
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
