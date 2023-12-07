# Declare TF variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
variable "aws_availabilityzone" {
  description = "AWS Availability Zone region"
  type        = string
  default     = "us-west-2a"
}

variable "key_name" {
  description = "Your AWS Key Pair name"
  type        = string
  default     = "terraform"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "Your AWS Access Key ID"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Your AWS Secret Key"
  type        = string
}

variable "hostname" {
  description = "EC2 instance Windows Computer Name"
  type        = string
  default     = "arc-sql-demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.xlarge"
  type        = string
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
  sensitive   = true
}

variable "servicePrincipalTenantId" {
  description = "Azure Tenant ID"
  type        = string
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