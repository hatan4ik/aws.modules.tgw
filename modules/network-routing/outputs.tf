output "attachment_domains" {
  description = "Network-account-assigned route domain by approved attachment key."
  value       = local.attachment_domains
}

output "accepted_attachments" {
  description = "Accepted cross-account attachment IDs and verified VPC-owner account IDs."
  value = {
    for key, attachment in aws_ec2_transit_gateway_vpc_attachment_accepter.approved :
    key => {
      id           = attachment.id
      vpc_owner_id = attachment.vpc_owner_id
      route_domain = local.attachment_domains[key]
    }
  }
}

output "propagation_ids" {
  description = "Explicit attachment-to-route-table propagation resource IDs keyed by attachment and destination domain."
  value       = { for key, propagation in aws_ec2_transit_gateway_route_table_propagation.approved : key => propagation.id }
}
