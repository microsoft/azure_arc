#
# Provider Configuration
#
terraform {
  backend "remote" {
    # The name of your Terraform Cloud organization.
    organization = "your-terraform-cloud-organization"
    
    # The name of the Terraform Cloud workspace to store Terraform state files in.
    workspaces {
      name = "your-terraform-cloud-workspace"
    }
  }
}

provider "aws" {
  region     = "us-west-2"
}

# Using these data sources allows the configuration to be
# generic for any region.
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

# Not required: currently used in conjuction with using
# icanhazip.com to determine local workstation external IP
# to open EC2 Security Group access to the Kubernetes cluster.
# See workstation-external-ip.tf for additional information.
rovider "http" {}
