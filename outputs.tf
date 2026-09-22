output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_route_table_id" {
  description = "Transit Gateway Route Table ID"
  value       = module.transit_gateway.transit_gateway_route_table_id
}

output "network_hub_vpc_id" {
  description = "Network Hub VPC ID"
  value       = module.network_hub_vpc.vpc_id
}

output "network_hub_vpc_cidr" {
  description = "Network Hub VPC CIDR"
  value       = module.network_hub_vpc.vpc_cidr_block
}

output "eks_cluster_id" {
  description = "EKS Cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster API Endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS Cluster Certificate Authority"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "opensearch_domain_endpoint" {
  description = "OpenSearch Domain Endpoint"
  value       = module.opensearch[0].domain_endpoint
}

output "karpenter_irsa_role_arn" {
  description = "Karpenter IRSA Role ARN"
  value       = module.karpenter_irsa[0].role_arn
}

output "eks_managed_node_groups" {
  description = "EKS Managed Node Group details"
  value = {
    linux_core = {
      id           = module.eks.eks_managed_node_groups["linux_core"].id
      role_arn     = module.eks.eks_managed_node_groups["linux_core"].iam_role_arn
      asg_name     = module.eks.eks_managed_node_groups["linux_core"].asg_name
    }
    windows_workloads = var.enable_windows_nodes ? {
      id           = module.eks.eks_managed_node_groups["windows_workloads"].id
      role_arn     = module.eks.eks_managed_node_groups["windows_workloads"].iam_role_arn
      asg_name     = module.eks.eks_managed_node_groups["windows_workloads"].asg_name
    } : null
  }
}

output "ssm_document_names" {
  description = "SSM Document names for diagnostics"
  value = {
    linux_triage   = aws_ssm_document.linux_diagnostics.name
    windows_triage = aws_ssm_document.windows_diagnostics.name
  }
}

output "security_group_ids" {
  description = "Security Group IDs"
  value = {
    eks_cluster_sg = module.eks.cluster_security_group_id
    eks_node_sg    = module.eks.node_security_group_id
  }
}
