variable "region" {
  description = "Region of the Transit Gateway and of the VPC. They must match."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Attachment name, 3-63 lowercase letters, digits, and hyphens."
  type        = string
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway that the Network account shared with this account through AWS RAM."
  type        = string
}

variable "vpc_id" {
  description = "ID of this account's VPC."
  type        = string
}

variable "subnet_ids" {
  description = "One private subnet per Availability Zone to attach, at least two."
  type        = set(string)
}

variable "attachment_key" {
  description = "Catalog key issued by the network team, 3-63 lowercase letters, digits, and hyphens. It identifies this attachment to them and is not a route domain."
  type        = string
}

variable "tags" {
  description = "Allocation and ownership tags. RouteDomain is reserved for the network account and rejected."
  type        = map(string)
  default     = {}
}
