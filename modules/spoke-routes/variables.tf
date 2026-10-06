variable "attachment" {
  description = "Phase 1 spoke attachment contract, normally module.vpc_attachment.attachment. The key and ID must match the Network account's Phase 2 receipt."
  type = object({
    id             = string
    attachment_key = string
  })
  nullable = false

  validation {
    condition     = can(regex("^tgw-attach-[0-9a-f]+$", var.attachment.id))
    error_message = "attachment.id must be a Transit Gateway attachment ID."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.attachment.attachment_key))
    error_message = "attachment.attachment_key must be 3-63 lowercase letters, digits, and hyphens and start with a letter."
  }
}

variable "network_acceptance_receipt" {
  description = "Phase 2 receipt from modules/network-routing.route_activation_receipts[attachment_key]. Routes remain blocked unless it proves the same attachment was owner-verified, associated, and propagated by the Network account."
  type = object({
    contract_version          = number
    ready                     = bool
    attachment_key            = string
    attachment_id             = string
    transit_gateway_id        = string
    vpc_owner_id              = string
    route_domain              = string
    associated_route_table_id = string
    association_id            = string
    propagation_ids           = list(string)
  })
  nullable = false

  validation {
    condition = (
      can(regex("^tgw-attach-[0-9a-f]+$", var.network_acceptance_receipt.attachment_id)) &&
      can(regex("^tgw-[0-9a-f]+$", var.network_acceptance_receipt.transit_gateway_id)) &&
      can(regex("^[0-9]{12}$", var.network_acceptance_receipt.vpc_owner_id)) &&
      can(regex("^tgw-rtb-[0-9a-f]+$", var.network_acceptance_receipt.associated_route_table_id))
    )
    error_message = "network_acceptance_receipt must contain valid Transit Gateway, attachment, route-table, and 12-digit owner account identifiers."
  }
}

variable "routes" {
  description = "Phase 3 VPC routes, keyed by a stable catalog name. Each route is installed only after the acceptance receipt passes every barrier."
  type = map(object({
    route_table_id         = string
    destination_cidr_block = string
  }))
  nullable = false

  validation {
    condition     = length(var.routes) > 0 && alltrue([for key in keys(var.routes) : can(regex("^[a-z][a-z0-9-]{2,62}$", key))])
    error_message = "routes must contain at least one entry whose key is 3-63 lowercase letters, digits, and hyphens and starts with a letter."
  }

  validation {
    condition = alltrue([
      for route in values(var.routes) :
      can(regex("^rtb-[0-9a-f]+$", route.route_table_id)) &&
      try(cidrsubnet(route.destination_cidr_block, 0, 0) == route.destination_cidr_block, false)
    ])
    error_message = "Every route needs a VPC route-table ID and a canonical IPv4 CIDR block whose host bits are zero."
  }

  validation {
    condition     = length(distinct([for route in values(var.routes) : "${route.route_table_id}|${route.destination_cidr_block}"])) == length(var.routes)
    error_message = "Each route-table ID and destination CIDR pair may appear only once."
  }
}
