resource "helm_release" "karpenter" {
  count      = var.enable_karpenter ? 1 : 0
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = "karpenter"
  version    = "v0.34.0"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa[0].role_arn
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_id
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter[0].name
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.karpenter,
    aws_iam_role_policy.karpenter_controller_policy[0]
  ]

  timeout = 600

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-karpenter"
    }
  )
}

resource "aws_sqs_queue" "karpenter" {
  count                     = var.enable_karpenter ? 1 : 0
  name                      = "${var.environment}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-karpenter-interruption"
    }
  )
}

resource "aws_sqs_queue_policy" "karpenter" {
  count     = var.enable_karpenter ? 1 : 0
  queue_url = aws_sqs_queue.karpenter[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter[0].arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  count       = var.enable_karpenter ? 1 : 0
  name        = "${var.environment}-karpenter-spot-interruption"
  description = "Route EC2 Spot Instance Interruption Warnings to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-karpenter-spot-interruption"
    }
  )
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  count      = var.enable_karpenter ? 1 : 0
  rule       = aws_cloudwatch_event_rule.karpenter_spot_interruption[0].name
  target_id  = "KarpenterSpotInterruptionQueue"
  arn        = aws_sqs_queue.karpenter[0].arn
}

resource "aws_iam_role_policy" "karpenter_controller_policy" {
  count       = var.enable_karpenter ? 1 : 0
  name_prefix = "karpenter-controller-policy-"
  role        = module.karpenter_irsa[0].role_name

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
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcs",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
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
      },
      {
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.eks_node_role.arn
        ]
      }
    ]
  })
}

resource "kubernetes_storage_class" "karpenter" {
  count = var.enable_karpenter ? 1 : 0
  metadata {
    name = "karpenter"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    iops      = "3000"
    throughput = "125"
  }

  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [module.eks]
}
