variable "name" {
  description = "Lowercase Transit Gateway hub name used in resource names and tags. At most 50 characters because the flow-log role is named <name>-tgw-flow-logs and IAM role names are limited to 64."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,49}$", var.name))
    error_message = "name must be 3-50 lowercase letters, digits, and hyphens and start with a letter; the flow-log IAM role is named <name>-tgw-flow-logs and IAM role names are limited to 64 characters."
  }
}

variable "amazon_side_asn" {
  description = "Approved private BGP ASN for the Amazon side of this regional Transit Gateway."
  type        = number
  nullable    = false

  validation {
    condition = (
      floor(var.amazon_side_asn) == var.amazon_side_asn &&
      ((var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) ||
      (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294))
    )
    error_message = "amazon_side_asn must be a whole-number private 16-bit (64512-65534) or 32-bit (4200000000-4294967294) ASN."
  }
}

variable "route_domains" {
  description = "Network-owned TGW route domains, one deny-by-default route table each. Attachments are associated later by the separate network-routing module. The default is the five domains of ADR 0003."
  type        = set(string)
  default     = ["prod", "non-prod", "shared", "inspection", "on-prem"]
  nullable    = false

  validation {
    condition     = length(var.route_domains) > 0 && alltrue([for domain in var.route_domains : can(regex("^[a-z][a-z0-9-]{1,30}$", domain))])
    error_message = "route_domains must contain one or more domain names of 2-31 lowercase letters, digits, and hyphens that start with a letter."
  }
}

variable "ram_principals" {
  description = "AWS account IDs or AWS Organizations organization/OU ARNs permitted to create VPC attachments to this TGW. All must be inside the organization: the share never allows external principals. null falls back to the deprecated ram_principal_arns; an empty set shares with nobody."
  type        = set(string)
  default     = null
  nullable    = true

  validation {
    condition = alltrue([
      for principal in coalesce(var.ram_principals, []) :
      can(regex("^[0-9]{12}$", principal)) ||
      can(regex("^arn:[^:]+:organizations::[0-9]{12}:organization/o-[a-z0-9-]+$", principal)) ||
      can(regex("^arn:[^:]+:organizations::[0-9]{12}:ou/o-[a-z0-9-]+/ou-[a-z0-9-]+$", principal))
    ])
    error_message = "ram_principals must contain 12-digit account IDs or AWS Organizations organization/OU ARNs; TGW shares cannot target IAM users or roles."
  }
}

variable "ram_principal_arns" {
  description = "Deprecated compatibility input, removed in v2. Use ram_principals, which also accepts 12-digit AWS account IDs. Ignored when ram_principals is set."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for principal in var.ram_principal_arns :
      can(regex("^[0-9]{12}$", principal)) ||
      can(regex("^arn:[^:]+:organizations::[0-9]{12}:organization/o-[a-z0-9-]+$", principal)) ||
      can(regex("^arn:[^:]+:organizations::[0-9]{12}:ou/o-[a-z0-9-]+/ou-[a-z0-9-]+$", principal))
    ])
    error_message = "ram_principal_arns must contain 12-digit account IDs or AWS Organizations organization/OU ARNs."
  }
}

variable "flow_log_retention_in_days" {
  description = "CloudWatch Logs retention for Transit Gateway Flow Logs. Network evidence is retained for at least one year."
  type        = number
  default     = 365
  nullable    = false

  validation {
    condition     = contains([365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_in_days)
    error_message = "flow_log_retention_in_days must be a supported CloudWatch Logs retention period of at least 365 days: 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, or 3653."
  }
}

variable "rejected_traffic_alarm_threshold" {
  description = "Rejected TGW flow-log records (dropped for lack of a route or by a blackhole route) that trigger the five-minute rejected-traffic alarm."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.rejected_traffic_alarm_threshold >= 1 && floor(var.rejected_traffic_alarm_threshold) == var.rejected_traffic_alarm_threshold
    error_message = "rejected_traffic_alarm_threshold must be a positive whole number."
  }
}

variable "rejected_traffic_alarm_actions" {
  description = "Optional SNS or incident-management action ARNs notified by the rejected-TGW-traffic alarm and the flow-log delivery-stopped alarm. CloudWatch allows at most five."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for action in var.rejected_traffic_alarm_actions : can(regex("^arn:[^:]+:[^:]+:[^:]*:[^:]*:.+$", action))])
    error_message = "rejected_traffic_alarm_actions must be ARNs, for example an SNS topic ARN."
  }

  validation {
    condition     = length(var.rejected_traffic_alarm_actions) <= 5
    error_message = "rejected_traffic_alarm_actions may contain at most five actions, the CloudWatch alarm limit."
  }
}

variable "tags" {
  description = "Additional required allocation and ownership tags. Name and Component tags are computed by the module and cannot be overridden."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for key in keys(var.tags) : !startswith(key, "aws:")])
    error_message = "tags must not use the reserved aws: prefix."
  }
}
