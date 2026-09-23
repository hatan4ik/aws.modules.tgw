locals {
  attachment_domains = {
    for key, attachment in var.attachments :
    key => lookup(var.approved_account_domains, attachment.account_id, "")
  }

  propagation_specs = {
    for spec in flatten([
      for attachment_key, attachment in var.attachments : [
        for destination_domain in lookup(var.propagation_matrix, local.attachment_domains[attachment_key], toset([])) : {
          attachment_key     = attachment_key
          destination_domain = destination_domain
        }
      ]
    ]) : "${spec.attachment_key}:${spec.destination_domain}" => spec
  }

  common_tags = merge(var.tags, {
    Component = "transit-gateway-network-routing"
  })
}
