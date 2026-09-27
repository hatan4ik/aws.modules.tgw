variable "name_prefix" {
  description = "Prefix of the disposable hub name; a random suffix is appended so concurrent runs never collide. The flow-log role, KMS alias, log group, and alarm inherit it, which is what the integration IAM policy is scoped to."
  type        = string
  default     = "tgw-it"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,42}$", var.name_prefix))
    error_message = "name_prefix must be 2-43 lowercase alphanumeric characters or hyphens starting with a letter, so the suffixed name satisfies the module's 50-character name rule."
  }
}

variable "tags" {
  description = "Tags applied to the hub under test in addition to the identifying defaults."
  type        = map(string)
  default     = {}
}
