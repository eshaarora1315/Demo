output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_security_group_id" {
  value = aws_ec2_security_group.eks_cluster.id
}

output "node_security_group_id" {
  value = aws_ec2_security_group.eks_nodes.id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_managed_node_groups" {
  value = module.eks.eks_managed_node_groups
}
