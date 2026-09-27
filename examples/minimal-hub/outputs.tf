output "transit_gateway" {
  description = "Hub TGW ID and ARN, the identifiers the network-routing module, workload attachments, and separately approved VPN or peering compositions consume."
  value       = module.hub.transit_gateway
}

output "route_table_ids" {
  description = "Route-domain to route-table ID map that the network account passes to modules/network-routing."
  value       = module.hub.route_table_ids
}

output "flow_logs" {
  description = "Flow log, encrypted log group, key, and rejected-traffic alarm identifiers."
  value       = module.hub.flow_logs
}
