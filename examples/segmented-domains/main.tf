# The Network account owns the hub and everything that decides who can reach
# whom. Its routing composition accepts each spoke's attachment, verifies the
# VPC owner, assigns the route domain, associates the attachment, propagates its
# routes only where the matrix allows, and blackholes what must never be
# reachable. The spoke supplies nothing but an attachment ID.
provider "aws" {
  region = var.region
}

locals {
  # The propagation policy is reviewed as code, not as a variable. A destination
  # that is not listed receives no route: deny by absence. prod and non-prod
  # never appear in each other's list, and the module rejects the plan if they
  # do (ADR 0003). Every domain that has an attachment needs an entry, even an
  # empty one. Reachability needs both directions: every pair below appears in
  # each other's list (on-prem reaches prod, non-prod, and shared, and each of
  # them propagates back into on-prem). A one-way entry gives a route with no
  # return path, so replies are dropped and the rejected-traffic alarm fires.
  propagation_matrix = {
    prod       = ["prod", "shared", "on-prem"]
    non-prod   = ["non-prod", "shared", "on-prem"]
    shared     = ["prod", "non-prod", "shared", "on-prem"]
    inspection = ["inspection"]
    on-prem    = ["prod", "non-prod", "shared", "on-prem"]
  }
}

module "hub" {
  source = "../../"

  name                           = var.name
  amazon_side_asn                = var.amazon_side_asn
  ram_principals                 = keys(var.approved_account_domains)
  rejected_traffic_alarm_actions = var.alarm_actions
  tags                           = var.tags
}

module "routing" {
  source = "../../modules/network-routing"

  route_table_ids          = module.hub.route_table_ids
  approved_account_domains = var.approved_account_domains
  attachments              = var.attachments
  propagation_matrix       = local.propagation_matrix

  # Non-production may only use the private routes it was explicitly given:
  # anything else inside the private supernet is dropped, and the rejected-
  # traffic alarm counts every packet that tries.
  static_routes = {
    non-prod-private-supernet = {
      route_table_domain     = "non-prod"
      destination_cidr_block = var.private_supernet
      blackhole              = true
    }
  }

  tags = var.tags
}
