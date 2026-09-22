output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  value = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.main.id
}

output "network_hub_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.network_hub.id
}
