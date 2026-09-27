variable "region" {
  description = "Region of the hub. A Transit Gateway is regional; add one hub per Region."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Hub name, 3-50 lowercase letters, digits, and hyphens. It prefixes every resource, including the flow-log role."
  type        = string
}

variable "amazon_side_asn" {
  description = "Private BGP ASN for the Amazon side of the hub, from the enterprise allocation: 64512-65534 or 4200000000-4294967294."
  type        = number
}

variable "tags" {
  description = "Allocation and ownership tags applied to every resource the hub creates."
  type        = map(string)
  default     = {}
}
