variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_vpc_id" {
  type        = string
  description = "Cluster VPC ID."
}

variable "cluster_subnet_ids" {
  type        = list
  description = "Cluster subnet IDs"
}

variable "workstation_cidr" {
  type        = string
  description = "Local workstation CIDR address."
}
