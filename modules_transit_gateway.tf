module "transit_gateway" {
  source = "./modules/transit-gateway"

  providers = {
    aws = aws.network_hub
  }

  environment      = var.environment
  project_name     = var.project_name
  common_tags      = local.common_tags
  primary_region   = var.primary_region
  
  network_hub_vpc_id = module.network_hub_vpc.vpc_id
  network_hub_subnets = module.network_hub_vpc.private_subnets

  workload_accounts = var.workload_account_ids
  eks_account_id    = var.eks_account_id
}

resource "aws_ec2_transit_gateway_route" "default_route" {
  provider                       = aws.network_hub
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.transit_gateway.network_hub_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_association" "network_hub" {
  provider                       = aws.network_hub
  transit_gateway_attachment_id  = module.transit_gateway.network_hub_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.transit_gateway_route_table_id
}
