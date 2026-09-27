output "transit_gateway" {
  description = "Hub TGW ID and ARN. Spokes in the shared organization or OUs use the ID to request attachments."
  value       = module.hub.transit_gateway
}

output "ram_resource_share_arn" {
  description = "RAM share ARN. Audit its principal associations to see exactly who may request attachments."
  value       = module.hub.ram_resource_share_arn
}
