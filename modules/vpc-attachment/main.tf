resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids                                      = tolist(var.subnet_ids)
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = var.vpc_id
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = var.appliance_mode_support ? "enable" : "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name          = var.name
    AttachmentKey = var.attachment_key
    Component     = "tgw-vpc-attachment"
  })
}
