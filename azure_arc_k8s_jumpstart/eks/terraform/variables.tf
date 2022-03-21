variable "aws_region" {
  type        = string
  description = "Target AWS region."
  default     = "us-west-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "arcdemo-cluster"
}
