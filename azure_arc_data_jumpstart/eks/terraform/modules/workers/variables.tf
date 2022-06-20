variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_subnet_ids" {
  type        = list
  description = "Cluster subnet IDs"
}
