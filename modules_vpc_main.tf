module "network_hub_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.network_hub
  }

  name = "${var.environment}-network-hub-vpc"
  cidr = "10.100.0.0/16"

  azs             = var.availability_zones
  public_subnets = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
  private_subnets = ["10.100.11.0/24", "10.100.12.0/24", "10.100.13.0/24"]
  intra_subnets   = ["10.100.21.0/24", "10.100.22.0/24", "10.100.23.0/24"]

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_vpn_gateway   = var.enable_vpn_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "Type" = "Public"
    "karpenter.sh/discovery" = "true"
  }

  private_subnet_tags = {
    "Type" = "Private"
    "karpenter.sh/discovery" = "true"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-network-hub-vpc"
    }
  )
}

resource "aws_security_group" "network_hub_sg" {
  name_prefix = "network-hub-"
  description = "Security group for Network Hub VPC"
  vpc_id      = module.network_hub_vpc.vpc_id
  provider    = aws.network_hub

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-network-hub-sg"
    }
  )
}

resource "aws_route_table" "network_hub_private" {
  vpc_id   = module.network_hub_vpc.vpc_id
  provider = aws.network_hub

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-network-hub-private-rt"
    }
  )
}

resource "aws_route_table_association" "network_hub_private" {
  count          = length(module.network_hub_vpc.private_subnets)
  subnet_id      = module.network_hub_vpc.private_subnets[count.index]
  route_table_id = aws_route_table.network_hub_private.id
  provider       = aws.network_hub
}
