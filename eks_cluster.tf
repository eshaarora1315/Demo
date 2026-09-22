module "eks_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-eks-vpc"
  cidr = "10.50.0.0/16"

  azs             = var.availability_zones
  public_subnets = ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24"]
  private_subnets = ["10.50.11.0/24", "10.50.12.0/24", "10.50.13.0/24"]
  intra_subnets   = ["10.50.21.0/24", "10.50.22.0/24", "10.50.23.0/24"]

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "Type"                           = "Public"
    "kubernetes.io/role/elb"         = "1"
    "karpenter.sh/discovery"         = var.eks_cluster_name
  }

  private_subnet_tags = {
    "Type"                           = "Private"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"         = var.eks_cluster_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-eks-vpc"
    }
  )
}

module "eks" {
  source = "./modules/eks"

  environment             = var.environment
  project_name            = var.project_name
  common_tags             = local.common_tags
  vpc_id                  = module.eks_vpc.vpc_id
  private_subnets         = module.eks_vpc.private_subnets
  eks_cluster_version     = var.eks_cluster_version
  eks_instance_types      = var.eks_instance_types
  eks_windows_instance_types = var.eks_windows_instance_types
  eks_desired_size        = var.eks_desired_size
  eks_min_size            = var.eks_min_size
  eks_max_size            = var.eks_max_size
  enable_windows_nodes    = var.enable_windows_nodes
  windows_desired_size    = var.windows_desired_size
  windows_min_size        = var.windows_min_size
  windows_max_size        = var.windows_max_size
  log_retention_days      = var.log_retention_days
  cloudwatch_log_kms_key_id = ""

  depends_on = [module.eks_vpc]
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${module.eks.cluster_id}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/eks/${module.eks.cluster_id}/cluster"
    }
  )
}
