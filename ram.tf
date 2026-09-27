# The share never allows principals outside the AWS Organization. Account IDs
# must therefore belong to the organization, and organization or OU ARNs
# require RAM sharing with AWS Organizations to be enabled by the management
# account.
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
  for_each = local.ram_principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this.arn
}
