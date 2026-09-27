output "transit_gateway" {
  description = "Hub TGW ID and ARN to hand to the spokes that request attachments."
  value       = module.hub.transit_gateway
}

output "ram_resource_share_arn" {
  description = "RAM share through which the approved accounts see the hub."
  value       = module.hub.ram_resource_share_arn
}

output "attachment_domains" {
  description = "Route domain the network account assigned to each attachment key."
  value       = module.routing.attachment_domains
}

output "accepted_attachments" {
  description = "Accepted attachment IDs with the verified VPC-owner account and assigned domain."
  value       = module.routing.accepted_attachments
}

output "propagation_ids" {
  description = "Propagation resource IDs keyed by attachment and destination domain."
  value       = module.routing.propagation_ids
}
