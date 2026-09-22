variable "name" {
  description = "Lowercase Transit Gateway hub name used in resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.name))
    error_message = "name must be 3-63 lowercase letters, digits, and hyphens and start with a letter."
  }
}

variable "amazon_side_asn" {
  description = "Approved private BGP ASN for the Amazon side of this regional Transit Gateway."
  type        = number
  nullable    = false

  validation {
    condition = (
      (var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) ||
      (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294)
    )
    error_message = "amazon_side_asn must be a valid private 16-bit or 32-bit ASN."
  }
}

variable "ram_principal_arns" {
  description = "AWS Organizations or account principals allowed to attach approved VPCs to this TGW through RAM."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for principal in var.ram_principal_arns : can(regex("^arn:[^:]+:(organizations|iam)::.+$", principal))])
    error_message = "ram_principal_arns must contain AWS Organizations or IAM principal ARNs."
  }
}

variable "tags" {
  description = "Additional required allocation and ownership tags. Name and Component tags are computed by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
