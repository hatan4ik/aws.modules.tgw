# Partition, region, and account are read once, only to build the KMS key policy
# and the flow-log role policies: those must name the log-group ARN before the
# log group exists, so the ARN is constructed rather than read from the resource.
data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_ec2_transit_gateway" "this" {
  description                     = "Segmented regional transit gateway ${var.name}"
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  encryption_support              = "enable"

  # Transit Gateway flow logs do not record multicast, so enabling it would
  # create a path the network evidence cannot see.
  multicast_support = "disable"

  # Cross-VPC security-group references would bypass the explicit, account-owned
  # security-group policy. Keep this disabled unless a future ADR changes it.
  security_group_referencing_support = "disable"

  # This module creates no VPN attachment, but the separately approved VPN
  # composition (ADR 0003, ADR 0005) attaches to this gateway and cannot set a
  # gateway-level option itself. ECMP lets that composition balance across
  # multiple VPN tunnels; it has no effect until a VPN attachment exists. It is
  # also the AWS default, so stating it changes nothing on an existing hub.
  vpn_ecmp_support = "enable"

  tags = local.common_tags
}

# One route table per domain. Nothing is associated with or propagated into
# them here: the network account's routing composition does that explicitly.
resource "aws_ec2_transit_gateway_route_table" "domain" {
  for_each = local.route_domains

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-${each.key}"
    RouteDomain = each.key
  })
}
