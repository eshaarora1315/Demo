terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "network_hub"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_hub_account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "security"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}
