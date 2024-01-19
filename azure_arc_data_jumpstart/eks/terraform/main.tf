terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  region = var.AWS_DEFAULT_REGION
}


variable "AWS_ACCESS_KEY_ID" {
  type = string
  description = "AWS Access key id"
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
  description = "AWS Access Secret"
  sensitive   = true
}
variable "AWS_DEFAULT_REGION" {
  type = string
  description = "the location of all AWS resources"
}
variable "resourceGroup" {
  type        = string
  description = "Azure Resource Group"
}

variable "spnClientId" {
  type        = string
  description = "Client id of the service principal"
}

variable "spnClientSecret" {
  type        = string
  description = "Client secret of the service principal"
  sensitive   = true
}

variable "spnAuthority" {
  type        = string
  description = "Authority for Service Principal authentication"
  default     = "https://login.microsoftonline.com"
}
variable "spnTenantId" {
  type        = string
  description = "Tenant id of the service principal"
}

variable "subscriptionId" {
  type        = string
  description = "Subscription ID"
}

variable "azureLocation" {
  type        = string
  description = "Location for all resources"
}

variable "workspaceName" {
  type        = string
  description = "Name for the environment Azure Log Analytics workspace"
}

variable "deploySQLMI" {
  type        = bool
  default = false
  description = "SQL Managed Instance deployment"
}

variable "SQLMIHA" {
  type        = bool
  default = false
  description = "SQL Managed Instance high-availability deployment"
}

variable "deployPostgreSQL" {
  type        = bool
  default = false
  description = "PostgreSQL deployment"
}
variable "customLocationObjectId" {
  type   = string
  description = "Custom Location object Id"
}
variable "clusterName" {
  type        = string
  default = "Arc-Data-EKS"
  description = "The name of the Kubernetes cluster resource."
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

variable "github_repo" {
  type        = string
  description = "Specify a GitHub repo (used for testing purposes)"
  default     = "microsoft"
}

variable "github_branch" {
  type        = string
  description = "Specify a GitHub branch (used for testing purposes)"
  default     = "main"
}

data "http" "workstation_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_availability_zones" "available" {}

# Override with variable or hardcoded value if necessary
locals {
  workstation_cidr = "${chomp(data.http.workstation_ip.body)}/32"
   template_base_url = "https://raw.githubusercontent.com/${var.github_repo}/azure_arc/${var.github_branch}/azure_arc_data_jumpstart/eks/terraform/"
}

resource "aws_vpc" "arcdemo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "arcdemo"
  }
}

resource "aws_subnet" "arcdemo" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.arcdemo.id

  tags = {
    Name = "arcdemo-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "arcdemo" {
  vpc_id = aws_vpc.arcdemo.id

  tags = {
    Name = "arcdemo"
  }
}

resource "aws_route_table" "arcdemo" {
  vpc_id = aws_vpc.arcdemo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.arcdemo.id
  }

  tags = {
    Name = "arcdemo"
  }
}

resource "aws_route_table_association" "arcdemo" {
  count = 2

  subnet_id      = aws_subnet.arcdemo.*.id[count.index]
  route_table_id = aws_route_table.arcdemo.id
}

module "eks_cluster" {
  source = "./modules/cluster"

  cluster_name       = var.clusterName
  cluster_vpc_id     = aws_vpc.arcdemo.id
  cluster_subnet_ids = aws_subnet.arcdemo[*].id
  workstation_cidr   = local.workstation_cidr

  depends_on = [aws_vpc.arcdemo, aws_subnet.arcdemo]
}

module "eks_workers" {
  source = "./modules/workers"

  cluster_name       = var.clusterName
  cluster_subnet_ids = aws_subnet.arcdemo[*].id

  depends_on = [module.eks_cluster]
}


module "client_VM"{
  source = "./modules/ClientVM"

  resourceGroup = var.resourceGroup
  spnClientId = var.spnClientId
  spnClientSecret = var.spnClientSecret
  spnTenantId = var.spnTenantId
  subscriptionId = var.subscriptionId
  azureLocation = var.azureLocation
  workspaceName = var.workspaceName
  deploySQLMI = var.deploySQLMI
  SQLMIHA = var.SQLMIHA
  deployPostgreSQL = var.deployPostgreSQL
  customLocationObjectId = var.customLocationObjectId
  templateBaseUrl = local.template_base_url
  awsDefaultRegion = var.AWS_DEFAULT_REGION
  awsAccessKeyId = var.AWS_ACCESS_KEY_ID
  awsSecretAccessKey = var.AWS_SECRET_ACCESS_KEY
  clusterName = var.clusterName

depends_on = [module.eks_workers]

}

output "client_vm_password_decrypted" {
  value = module.client_VM.password_decrypted
}