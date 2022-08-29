output "cluster_endpoint" {
  value = aws_eks_cluster.arcdemo.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.arcdemo.certificate_authority.0.data
}
