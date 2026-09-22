terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

resource "aws_ec2_security_group" "opensearch" {
  name_prefix = "opensearch-"
  description = "Security group for OpenSearch domain"
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
      Name = "${var.environment}-opensearch-sg"
    }
  )
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.environment}-opensearch-encryption-policy"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.opensearch_domain_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.environment}-opensearch-network-policy"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_domain_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.opensearch_domain_name}"]
        }
      ]
      AllowFromPublic = false
    }
  ])
}

resource "aws_opensearchserverless_security_policy" "data" {
  name = "${var.environment}-opensearch-data-policy"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_domain_name}"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_domain_name}/*"]
        }
      ]
      Principal = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
      Effect = "Allow"
    }
  ])
}

resource "aws_opensearchserverless_collection" "opensearch" {
  name            = var.opensearch_domain_name
  type            = "SEARCH"
  standby_replicas = "ENABLED"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_security_policy.data
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-opensearch-collection"
    }
  )
}

resource "aws_kinesis_firehose_delivery_stream" "logs_to_opensearch" {
  name            = "${var.environment}-logs-to-opensearch"
  destination     = "opensearch"
  delivery_stream_type = "DirectPut"

  opensearch_configuration {
    domain_arn            = aws_opensearchserverless_collection.opensearch.arn
    role_arn              = aws_iam_role.firehose_role.arn
    index_name            = "logs-${var.environment}"
    index_rotation_period = "OneDay"
    buffering_hints {
      interval_in_seconds = 60
      size_in_m_bs        = 128
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-logs-to-opensearch"
    }
  )
}

resource "aws_iam_role" "firehose_role" {
  name_prefix = "firehose-opensearch-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "firehose_policy" {
  name_prefix = "firehose-opensearch-policy-"
  role        = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.opensearch.arn
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
