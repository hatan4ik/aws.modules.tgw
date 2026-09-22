output "attachment" {
  description = "Attachment ID and selected route domain for the Network account's separate acceptance/association root."
  value = {
    id           = aws_ec2_transit_gateway_vpc_attachment.this.id
    route_domain = var.route_domain
  }
}
