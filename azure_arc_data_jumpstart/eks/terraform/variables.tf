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

variable "key_pair_filename" {
  description = "Your AWS Key Pair *.pem filename"
  type        = string
  default     = "terraform.pem"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "Your AWS Access Key ID"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Your AWS Secret Key"
  type        = string
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

variable "REGISTRY_USERNAME" {
  description = "Azure Arc Data - Private Preview Container Registry username"
  type        = string
}

variable "REGISTRY_PASSWORD" {
  description = "Azure Arc Data - Private Preview Container Registry password"
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

variable "hostname" {
  description = "EC2 Client instance Windows hostname"
  type        = string
  default     = "arc-data-client"
}

variable "cluster-name" {
  description = "EKS cluster name"
  default     = "arc-data-eks"
  type        = string
}

variable "eks_instance_types" {
  description = "EKS node instance type"
  default     = "t3.xlarge"
  type        = string
}

variable "windows_instance_types" {
  description = "EC2 Client instance Windows type"
  default     = "t2.large"
  type        = string
}