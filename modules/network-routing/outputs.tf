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

output "route_activation_receipts" {
  description = "Machine-readable Phase 2 completion receipts. A spoke must consume its receipt through modules/spoke-routes before creating VPC routes to the Transit Gateway. Each receipt is emitted only after owner verification, route-table association, and every declared propagation for that attachment are in the applied network state."
  value = {
    for key, attachment in aws_ec2_transit_gateway_vpc_attachment_accepter.approved :
    key => {
      contract_version          = 1
      ready                     = true
      attachment_key            = key
      attachment_id             = attachment.transit_gateway_attachment_id
      transit_gateway_id        = attachment.transit_gateway_id
      vpc_owner_id              = attachment.vpc_owner_id
      route_domain              = local.attachment_domains[key]
      associated_route_table_id = aws_ec2_transit_gateway_route_table_association.approved[key].transit_gateway_route_table_id
      association_id            = aws_ec2_transit_gateway_route_table_association.approved[key].id
      propagation_ids = sort([
        for propagation_key, propagation in aws_ec2_transit_gateway_route_table_propagation.approved :
        propagation.id if local.propagation_specs[propagation_key].attachment_key == key
      ])
    }
  }
}

output "propagation_ids" {
  description = "Explicit attachment-to-route-table propagation resource IDs keyed by attachment and destination domain."
  value       = { for key, propagation in aws_ec2_transit_gateway_route_table_propagation.approved : key => propagation.id }
}
