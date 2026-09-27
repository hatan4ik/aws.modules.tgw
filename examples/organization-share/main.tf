# Share the hub with the AWS Organization, or with chosen organizational units,
# instead of listing accounts one by one. New accounts that land in the
# organization (or in a listed OU) can then see the Transit Gateway and request
# an attachment. Seeing the hub grants nothing: with automatic acceptance off and
# no default route table, an attachment does nothing until the network account
# accepts, classifies, and routes it.
#
# The share never allows principals outside the organization
# (allow_external_principals = false). Run with credentials for the Network
# account, which must be a member of the organization.
provider "aws" {
  region = var.region
}

locals {
  # One principal for the whole organization, or one per OU. Sharing with the
  # organization and an OU inside it is redundant.
  ram_principals = length(var.workload_ou_arns) == 0 ? [var.organization_arn] : var.workload_ou_arns
}

module "hub" {
  source = "../../"

  name                           = var.name
  amazon_side_asn                = var.amazon_side_asn
  ram_principals                 = local.ram_principals
  rejected_traffic_alarm_actions = var.alarm_actions
  tags                           = var.tags
}
