variable "name" {
  description = "Lowercase attachment name used in tags."
  type        = string
  nullable    = false
}

variable "transit_gateway_id" {
  description = "ID of the approved regional Transit Gateway shared with this workload account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^tgw-[0-9a-f]+$", var.transit_gateway_id))
    error_message = "transit_gateway_id must be a Transit Gateway ID."
  }
}

variable "vpc_id" {
  description = "ID of the private workload VPC receiving the attachment."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID."
  }
}

variable "subnet_ids" {
  description = "One private subnet per selected AZ for the TGW attachment."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2 && alltrue([for subnet_id in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", subnet_id))])
    error_message = "subnet_ids must contain at least two private subnet IDs."
  }
}

variable "route_domain" {
  description = "ADR-defined TGW route domain selected for this attachment."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["prod", "non-prod", "shared", "inspection", "on-prem"], var.route_domain)
    error_message = "route_domain must be prod, non-prod, shared, inspection, or on-prem."
  }
}

variable "tags" {
  description = "Additional required allocation and ownership tags. Name and RouteDomain are computed by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
