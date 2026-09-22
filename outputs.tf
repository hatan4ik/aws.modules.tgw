output "transit_gateway" {
  description = "Regional TGW identifiers needed by workload attachment and peering composition."
  value = {
    id  = aws_ec2_transit_gateway.this.id
    arn = aws_ec2_transit_gateway.this.arn
  }
}

output "route_table_ids" {
  description = "Fixed route-domain to TGW route-table ID mapping for explicit attachment association."
  value       = { for domain, route_table in aws_ec2_transit_gateway_route_table.domain : domain => route_table.id }
}

output "ram_resource_share_arn" {
  description = "RAM resource share ARN used to audit approved attachment principals."
  value       = aws_ram_resource_share.this.arn
}
