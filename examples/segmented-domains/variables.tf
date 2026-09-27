variable "region" {
  description = "Region of the hub."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Hub name, 3-50 lowercase letters, digits, and hyphens."
  type        = string
}

variable "amazon_side_asn" {
  description = "Private BGP ASN for the Amazon side of the hub, from the enterprise allocation."
  type        = number
}

variable "approved_account_domains" {
  description = "Workload account ID to its one route domain, for example { \"111122223333\" = \"prod\" }. These accounts are also the RAM principals that may request attachments. Only the network account edits this map."
  type        = map(string)
}

variable "attachments" {
  description = "Attachments the network account has decided to accept, keyed by the catalog key the spoke was given. Each names the attachment ID the spoke reported and the account expected to own the VPC. Empty until the first spoke has requested an attachment."
  type = map(object({
    attachment_id = string
    account_id    = string
  }))
  default = {}
}

variable "private_supernet" {
  description = "Private address supernet, for example an IPAM top-level pool CIDR, that is blackholed in the non-prod route table so non-production reaches only the routes propagated to it."
  type        = string
}

variable "alarm_actions" {
  description = "SNS topic or incident-management ARNs notified when the hub drops traffic for lack of a route or at a blackhole. At most five."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Allocation and ownership tags applied to every resource."
  type        = map(string)
  default     = {}
}
