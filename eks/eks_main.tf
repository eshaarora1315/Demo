terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

locals {
  cluster_name = "${var.environment}-enterprise-eks"
}

resource "aws_ec2_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  description = "EKS Cluster Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.cluster_name}-sg"
    }
  )
}

resource "aws_ec2_security_group" "eks_nodes" {
  name_prefix = "eks-nodes-"
  description = "EKS Nodes Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_ec2_security_group.eks_cluster.id]
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = [aws_ec2_security_group.eks_cluster.id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.cluster_name}-nodes-sg"
    }
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version
  cluster_ip_family = "ipv4"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  cluster_security_group_id = aws_ec2_security_group.eks_cluster.id
  node_security_group_id    = aws_ec2_security_group.eks_nodes.id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  cloudwatch_log_group_retention_in_days = var.log_retention_days
  cloudwatch_log_group_kms_key_id        = var.cloudwatch_log_kms_key_id

  cluster_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  eks_managed_node_groups = {
    linux_core = {
      name         = "${local.cluster_name}-linux-core"
      min_size     = var.eks_min_size
      max_size     = var.eks_max_size
      desired_size = var.eks_desired_size

      instance_types = var.eks_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"

      capacity_type = "on-demand"

      disk_size = 100

      labels = {
        Environment = var.environment
        NodeType    = "linux-core"
      }

      taints = []

      tags = merge(
        var.common_tags,
        {
          NodeGroup = "linux-core"
        }
      )
    }

    windows_workloads = var.enable_windows_nodes ? {
      name         = "${local.cluster_name}-windows-workloads"
      min_size     = var.windows_min_size
      max_size     = var.windows_max_size
      desired_size = var.windows_desired_size

      instance_types = var.eks_windows_instance_types
      ami_type       = "WINDOWS_CORE_2022_x86_64"

      capacity_type = "on-demand"

      disk_size = 150

      labels = {
        Environment = var.environment
        NodeType    = "windows"
      }

      tags = merge(
        var.common_tags,
        {
          NodeGroup = "windows-workloads"
        }
      )
    } : null
  }

  tags = merge(
    var.common_tags,
    {
      Name = local.cluster_name
    }
  )
}

resource "aws_iam_role" "eks_pod_identity_role" {
  name_prefix = "eks-pod-identity-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = module.eks.cluster_arn
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${local.cluster_name}-pod-identity-role"
    }
  )
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = module.eks.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.eks_pod_identity_role.arn
}

resource "aws_iam_role_policy" "eks_pod_identity_policy" {
  name_prefix = "eks-pod-identity-policy-"
  role        = aws_iam_role.eks_pod_identity_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = kubernetes_namespace.karpenter.metadata[0].name
  }

  depends_on = [kubernetes_namespace.karpenter]
}

resource "kubernetes_cluster_role_binding" "karpenter_admin" {
  metadata {
    name = "karpenter-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:masters"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.karpenter.metadata[0].name
    namespace = kubernetes_service_account.karpenter.metadata[0].namespace
  }

  depends_on = [kubernetes_service_account.karpenter]
}
