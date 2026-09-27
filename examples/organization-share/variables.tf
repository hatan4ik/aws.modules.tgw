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

variable "organization_arn" {
  description = "ARN of the AWS Organization to share with, in the form arn:aws:organizations::<management-account-id>:organization/o-xxxxxxxxxx."
  type        = string
}

variable "workload_ou_arns" {
  description = "Organizational unit ARNs to share with instead of the whole organization, in the form arn:aws:organizations::<management-account-id>:ou/o-xxxxxxxxxx/ou-xxxx-xxxxxxxx. Empty shares with the organization."
  type        = set(string)
  default     = []
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
