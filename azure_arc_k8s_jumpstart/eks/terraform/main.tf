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
  region = var.AWS_REGION
}

data "http" "workstation_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_availability_zones" "available" {}

# Override with variable or hardcoded value if necessary
locals {
  workstation_cidr = "${chomp(data.http.workstation_ip.body)}/32"
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

  cluster_name       = var.cluster_name
  cluster_vpc_id     = aws_vpc.arcdemo.id
  cluster_subnet_ids = aws_subnet.arcdemo[*].id
  workstation_cidr   = local.workstation_cidr

  depends_on = [aws_vpc.arcdemo, aws_subnet.arcdemo]
}

module "eks_workers" {
  source = "./modules/workers"

  cluster_name       = var.cluster_name
  cluster_subnet_ids = aws_subnet.arcdemo[*].id

  depends_on = [module.eks_cluster]
}
