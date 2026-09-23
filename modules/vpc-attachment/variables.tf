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

variable "attachment_key" {
  description = "Network-catalog key used by the TGW owner to locate and classify this attachment. It is not a route domain."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.attachment_key))
    error_message = "attachment_key must be 3-63 lowercase letters, digits, and hyphens and start with a letter."
  }
}

variable "appliance_mode_support" {
  description = "Enable only for a reviewed inspection appliance attachment that requires AZ-affine return traffic. Workload attachments keep it disabled."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Additional required allocation and ownership tags. Name and RouteDomain are computed by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
