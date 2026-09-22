resource "aws_iam_role" "eks_pod_execution_role" {
  name_prefix = "eks-pod-execution-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "eks-pod-execution-role"
    }
  )
}

resource "aws_iam_role_policy" "eks_pod_execution_policy" {
  name_prefix = "eks-pod-execution-policy-"
  role        = aws_iam_role.eks_pod_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "ec2:RunInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/karpenter.sh/do-not-evict" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "workload_pod_role" {
  name_prefix = "workload-pod-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "workload-pod-role"
    }
  )
}

resource "aws_iam_role_policy" "workload_pod_policy" {
  name_prefix = "workload-pod-policy-"
  role        = aws_iam_role.workload_pod_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-workload-data",
          "arn:aws:s3:::${var.project_name}-workload-data/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/*"
      }
    ]
  })
}

resource "aws_iam_role" "eks_node_role" {
  name_prefix = "eks-node-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "eks-node-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy" "eks_node_custom_policy" {
  name_prefix = "eks-node-custom-policy-"
  role        = aws_iam_role.eks_node_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

module "karpenter_irsa" {
  count  = var.enable_karpenter ? 1 : 0
  source = "./modules/irsa"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")
  
  namespace       = "karpenter"
  service_account = "karpenter"
  role_name_prefix = "${var.environment}-karpenter-"
  common_tags     = local.common_tags
}
