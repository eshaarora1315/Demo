terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

resource "aws_ec2_transit_gateway" "main" {
  description                     = "Enterprise Transit Gateway for ${var.environment}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                      = "enable"
  vpn_ecn_support                  = "enable"
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-tgw"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-tgw-rt"
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "network_hub" {
  transit_gateway_id                  = aws_ec2_transit_gateway.main.id
  vpc_id                              = var.network_hub_vpc_id
  subnet_ids                          = var.network_hub_subnets
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-network-hub-attachment"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "network_hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network_hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route" "network_hub_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network_hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}
