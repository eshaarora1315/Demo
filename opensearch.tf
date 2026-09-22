module "opensearch" {
  count = var.centralized_logging_enabled ? 1 : 0
  source = "./modules/opensearch"

  providers = {
    aws = aws.security
  }

  environment              = var.environment
  project_name             = var.project_name
  common_tags              = local.common_tags
  opensearch_domain_name   = var.opensearch_domain_name
  opensearch_version       = var.opensearch_version
  vpc_id                   = module.network_hub_vpc.vpc_id
  private_subnets         = module.network_hub_vpc.private_subnets
  master_user_name        = "admin"
  master_user_password    = random_password.opensearch_master_password[0].result

  instance_type           = "t3.small.opensearch"
  instance_count          = 3
  warm_instance_enabled   = false
  ebs_volume_size         = 50
  ebs_volume_type         = "gp3"
  
  log_retention_days      = var.log_retention_days

  depends_on = [module.network_hub_vpc]
}

resource "random_password" "opensearch_master_password" {
  count   = var.centralized_logging_enabled ? 1 : 0
  length  = 16
  special = true
}

resource "aws_cloudwatch_log_resource_policy" "opensearch_logs" {
  count = var.centralized_logging_enabled ? 1 : 0
  policy_name = "${var.environment}-opensearch-logs-policy"

  policy_text = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "logs:PutLogEvents"
        Resource = "arn:aws:logs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
  count             = var.centralized_logging_enabled ? 1 : 0
  name              = "/aws/opensearch/${var.environment}/application-logs"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/opensearch/${var.environment}/application-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "opensearch_index_logs" {
  count             = var.centralized_logging_enabled ? 1 : 0
  name              = "/aws/opensearch/${var.environment}/index-logs"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/opensearch/${var.environment}/index-logs"
    }
  )
}

data "aws_caller_identity" "current" {}
