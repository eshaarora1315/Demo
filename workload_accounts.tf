provider "aws" {
  alias  = "workload_dev"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_ids.dev}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "workload_staging"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_ids.staging}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "workload_prod"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_ids.prod}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = local.common_tags
  }
}

module "workload_dev_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.workload_dev
  }

  name = "${var.environment}-dev-workload-vpc"
  cidr = "10.10.0.0/16"

  azs             = var.availability_zones
  public_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  intra_subnets   = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]

  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-dev-workload-vpc"
      Env  = "dev"
    }
  )
}

module "workload_staging_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.workload_staging
  }

  name = "${var.environment}-staging-workload-vpc"
  cidr = "10.20.0.0/16"

  azs             = var.availability_zones
  public_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  private_subnets = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
  intra_subnets   = ["10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"]

  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-staging-workload-vpc"
      Env  = "staging"
    }
  )
}

module "workload_prod_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.workload_prod
  }

  name = "${var.environment}-prod-workload-vpc"
  cidr = "10.30.0.0/16"

  azs             = var.availability_zones
  public_subnets = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
  private_subnets = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24"]
  intra_subnets   = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]

  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-prod-workload-vpc"
      Env  = "prod"
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev_workload" {
  provider                                        = aws.workload_dev
  transit_gateway_id                              = module.transit_gateway.transit_gateway_id
  vpc_id                                          = module.workload_dev_vpc.vpc_id
  subnet_ids                                      = module.workload_dev_vpc.private_subnets
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-dev-workload-tgw-attachment"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "dev_workload" {
  provider                       = aws.network_hub
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev_workload.id
  transit_gateway_route_table_id = module.transit_gateway.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "staging_workload" {
  provider                                        = aws.workload_staging
  transit_gateway_id                              = module.transit_gateway.transit_gateway_id
  vpc_id                                          = module.workload_staging_vpc.vpc_id
  subnet_ids                                      = module.workload_staging_vpc.private_subnets
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-staging-workload-tgw-attachment"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "staging_workload" {
  provider                       = aws.network_hub
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.staging_workload.id
  transit_gateway_route_table_id = module.transit_gateway.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod_workload" {
  provider                                        = aws.workload_prod
  transit_gateway_id                              = module.transit_gateway.transit_gateway_id
  vpc_id                                          = module.workload_prod_vpc.vpc_id
  subnet_ids                                      = module.workload_prod_vpc.private_subnets
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-prod-workload-tgw-attachment"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "prod_workload" {
  provider                       = aws.network_hub
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_workload.id
  transit_gateway_route_table_id = module.transit_gateway.transit_gateway_route_table_id
}
