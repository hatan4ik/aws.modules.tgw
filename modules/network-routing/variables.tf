variable "route_table_ids" {
  description = "Network-account-owned map of route domain to TGW route-table ID, normally output by the TGW hub module."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.route_table_ids) > 0 && alltrue([for id in values(var.route_table_ids) : can(regex("^tgw-rtb-[0-9a-f]+$", id))])
    error_message = "route_table_ids must contain one or more Transit Gateway route-table IDs."
  }
}

variable "approved_account_domains" {
  description = "Network-owned map of workload AWS account ID to its only permitted TGW route domain. Spoke code cannot select a domain."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for account_id in keys(var.approved_account_domains) : can(regex("^[0-9]{12}$", account_id))])
    error_message = "approved_account_domains keys must be 12-digit AWS account IDs."
  }

}

variable "attachments" {
  description = "Network-approved cross-account VPC attachment IDs and their expected VPC-owner account IDs. Route domains are intentionally absent."
  type = map(object({
    attachment_id = string
    account_id    = string
  }))
  nullable = false

  validation {
    condition = alltrue([
      for attachment in values(var.attachments) :
      can(regex("^tgw-attach-[0-9a-f]+$", attachment.attachment_id)) &&
      can(regex("^[0-9]{12}$", attachment.account_id))
    ])
    error_message = "Every attachment needs a TGW attachment ID and a 12-digit expected VPC-owner account ID."
  }

  validation {
    condition     = length(distinct([for attachment in values(var.attachments) : attachment.attachment_id])) == length(var.attachments)
    error_message = "An attachment ID may appear only once in the network-account attachment catalog."
  }
}

variable "propagation_matrix" {
  description = "Network-owned source-domain to destination-route-domain propagation policy. Omitted destinations receive no propagated route."
  type        = map(set(string))
  nullable    = false

}

variable "static_routes" {
  description = "Explicit network-account routes. A route is either a blackhole or targets an approved attachment key; it never falls back to a default route."
  type = map(object({
    route_table_domain     = string
    destination_cidr_block = string
    blackhole              = bool
    target_attachment_key  = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for route in values(var.static_routes) :
      can(cidrhost(route.destination_cidr_block, 0)) &&
      (route.blackhole ? route.target_attachment_key == null : route.target_attachment_key != null)
    ])
    error_message = "Each static route needs a CIDR and exactly one of blackhole=true or target_attachment_key."
  }
}

variable "tags" {
  description = "Additional ownership and allocation tags applied to network-account routing resources."
  type        = map(string)
  default     = {}
  nullable    = false
}
