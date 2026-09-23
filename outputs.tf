output "transit_gateway" {
  description = "Regional TGW identifiers needed by separately approved network routing, workload attachment, peering, and VPN composition."
  value = {
    id  = aws_ec2_transit_gateway.this.id
    arn = aws_ec2_transit_gateway.this.arn
  }
}

output "route_table_ids" {
  description = "Network-owned route-domain to TGW route-table ID mapping consumed by the separate network-routing module."
  value       = { for domain, route_table in aws_ec2_transit_gateway_route_table.domain : domain => route_table.id }
}

output "ram_resource_share_arn" {
  description = "RAM resource share ARN used to audit approved TGW attachment principals."
  value       = aws_ram_resource_share.this.arn
}

output "flow_logs" {
  description = "Transit Gateway Flow Log, encrypted log group, KMS key, and rejected-traffic alarm identifiers."
  value = {
    id                   = aws_flow_log.transit_gateway.id
    log_group_name       = aws_cloudwatch_log_group.flow_logs.name
    kms_key_arn          = aws_kms_key.flow_logs.arn
    rejected_traffic_arn = aws_cloudwatch_metric_alarm.rejected_traffic.arn
  }
}
