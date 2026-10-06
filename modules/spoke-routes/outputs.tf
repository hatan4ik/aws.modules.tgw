output "routes" {
  description = "Activated VPC routes and the verified network receipt identity that authorized them."
  value = {
    for key, route in aws_route.transit_gateway : key => {
      id                     = route.id
      route_table_id         = route.route_table_id
      destination_cidr_block = route.destination_cidr_block
      transit_gateway_id     = route.transit_gateway_id
      attachment_id          = var.network_acceptance_receipt.attachment_id
      route_domain           = var.network_acceptance_receipt.route_domain
    }
  }
}
