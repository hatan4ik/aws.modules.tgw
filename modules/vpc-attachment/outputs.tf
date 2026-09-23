output "attachment" {
  description = "Attachment ID and network-catalog key for the Network account's separate acceptance/association root."
  value = {
    id                    = aws_ec2_transit_gateway_vpc_attachment.this.id
    attachment_key        = var.attachment_key
    appliance_mode_enable = var.appliance_mode_support
  }
}
