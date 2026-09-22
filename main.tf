resource "aws_ec2_transit_gateway" "this" {
  description                        = "Segmented regional transit gateway ${var.name}"
  amazon_side_asn                    = var.amazon_side_asn
  auto_accept_shared_attachments     = "disable"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  dns_support                        = "enable"
  encryption_support                 = "enable"
  security_group_referencing_support = "disable"
  vpn_ecmp_support                   = "enable"

  tags = local.common_tags
}

resource "aws_ec2_transit_gateway_route_table" "domain" {
  for_each = local.route_domains

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-${each.key}"
    RouteDomain = each.key
  })
}

resource "aws_ram_resource_share" "this" {
  name                      = "${var.name}-attachment-share"
  allow_external_principals = false

  tags = local.common_tags
}

resource "aws_ram_resource_association" "transit_gateway" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.this.arn
}

resource "aws_ram_principal_association" "approved_principal" {
  for_each = var.ram_principal_arns

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this.arn
}
