mock_provider "aws" {}

variables {
  route_table_ids = {
    prod       = "tgw-rtb-0123abcd"
    non-prod   = "tgw-rtb-4567cdef"
    shared     = "tgw-rtb-89abcdef"
    inspection = "tgw-rtb-01234567"
    on-prem    = "tgw-rtb-89abcd01"
  }

  approved_account_domains = {
    "111122223333" = "prod"
    "444455556666" = "non-prod"
    "777788889999" = "shared"
  }

  attachments = {
    prod-app = {
      attachment_id = "tgw-attach-0123abcd"
      account_id    = "111122223333"
    }
    nonprod-app = {
      attachment_id = "tgw-attach-4567cdef"
      account_id    = "444455556666"
    }
    shared-services = {
      attachment_id = "tgw-attach-89abcdef"
      account_id    = "777788889999"
    }
  }

  # Explicitly omit prod -> non-prod and non-prod -> prod. ADR 0003 requires
  # the module to reject either direction, not merely to leave it out.
  propagation_matrix = {
    prod       = ["prod", "shared", "on-prem"]
    non-prod   = ["non-prod", "shared"]
    shared     = ["prod", "non-prod", "shared"]
    inspection = ["inspection"]
    on-prem    = ["prod", "non-prod", "shared", "on-prem"]
  }

  static_routes = {
    nonprod-private-block = {
      route_table_domain     = "non-prod"
      destination_cidr_block = "10.0.0.0/8"
      blackhole              = true
    }
  }
}

run "plans_network_owned_association_and_deny_by_absence_propagation" {
  command = plan

  assert {
    condition = (
      aws_ec2_transit_gateway_route_table_association.approved["prod-app"].transit_gateway_route_table_id == var.route_table_ids["prod"] &&
      aws_ec2_transit_gateway_route_table_association.approved["nonprod-app"].transit_gateway_route_table_id == var.route_table_ids["non-prod"] &&
      aws_ec2_transit_gateway_route_table_association.approved["shared-services"].transit_gateway_route_table_id == var.route_table_ids["shared"]
    )
    error_message = "The network account must associate every attachment with the route table of the domain it assigned, and no other."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_association.approved) == 3
    error_message = "Each approved attachment has exactly one association."
  }

  assert {
    condition = toset(keys(aws_ec2_transit_gateway_route_table_propagation.approved)) == toset([
      "prod-app:prod", "prod-app:shared", "prod-app:on-prem",
      "nonprod-app:non-prod", "nonprod-app:shared",
      "shared-services:prod", "shared-services:non-prod", "shared-services:shared",
    ])
    error_message = "Only the approved propagation matrix may create propagated routes."
  }

  assert {
    condition     = !contains(keys(aws_ec2_transit_gateway_route_table_propagation.approved), "prod-app:non-prod") && !contains(keys(aws_ec2_transit_gateway_route_table_propagation.approved), "nonprod-app:prod")
    error_message = "The policy must not leak production and non-production routes."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route_table_propagation.approved["prod-app:shared"].transit_gateway_route_table_id == var.route_table_ids["shared"]
    error_message = "A propagation lands in the destination domain's route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["nonprod-private-block"].blackhole
    error_message = "Explicit forbidden prefixes must remain blackhole routes."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["nonprod-private-block"].transit_gateway_attachment_id == null && aws_ec2_transit_gateway_route.static["nonprod-private-block"].transit_gateway_route_table_id == var.route_table_ids["non-prod"]
    error_message = "A blackhole route has no target and is installed in the named domain's table."
  }

  assert {
    condition     = output.attachment_domains == { prod-app = "prod", nonprod-app = "non-prod", shared-services = "shared" }
    error_message = "attachment_domains must report the network-assigned domain per attachment key."
  }
}

run "accepts_attachments_without_any_default_route_table" {
  command = plan

  assert {
    condition = alltrue([
      for accepter in values(aws_ec2_transit_gateway_vpc_attachment_accepter.approved) :
      accepter.transit_gateway_default_route_table_association == false && accepter.transit_gateway_default_route_table_propagation == false
    ])
    error_message = "An accepted attachment must never join a default route table."
  }

  assert {
    condition     = toset(keys(aws_ec2_transit_gateway_vpc_attachment_accepter.approved)) == toset(["prod-app", "nonprod-app", "shared-services"]) && aws_ec2_transit_gateway_vpc_attachment_accepter.approved["prod-app"].transit_gateway_attachment_id == "tgw-attach-0123abcd"
    error_message = "Exactly the catalog attachments are accepted, by their catalog IDs."
  }
}

run "computes_classification_tags_from_the_network_catalog" {
  command = plan

  variables {
    tags = {
      Owner       = "network"
      RouteDomain = "prod"
      Component   = "spoofed"
    }
  }

  assert {
    condition = (
      aws_ec2_transit_gateway_vpc_attachment_accepter.approved["nonprod-app"].tags["RouteDomain"] == "non-prod" &&
      aws_ec2_transit_gateway_vpc_attachment_accepter.approved["nonprod-app"].tags["Name"] == "nonprod-app" &&
      aws_ec2_transit_gateway_vpc_attachment_accepter.approved["nonprod-app"].tags["Component"] == "transit-gateway-network-routing" &&
      aws_ec2_transit_gateway_vpc_attachment_accepter.approved["nonprod-app"].tags["Owner"] == "network"
    )
    error_message = "RouteDomain, Name, and Component come from the network catalog; caller tags are kept but never override them."
  }
}

run "routes_to_an_approved_attachment_from_a_permitted_table" {
  command = plan

  variables {
    static_routes = {
      shared-services-from-prod = {
        route_table_domain     = "prod"
        destination_cidr_block = "10.20.0.0/16"
        blackhole              = false
        target_attachment_key  = "shared-services"
      }
      prod-from-shared = {
        route_table_domain     = "shared"
        destination_cidr_block = "10.10.0.0/16"
        blackhole              = false
        target_attachment_key  = "prod-app"
      }
      ipv6-block = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "2001:db8::/32"
        blackhole              = true
      }
    }
  }

  assert {
    condition     = toset(keys(aws_ec2_transit_gateway_route.static)) == toset(["shared-services-from-prod", "prod-from-shared", "ipv6-block"])
    error_message = "Every declared static route is created."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["shared-services-from-prod"].blackhole == false && aws_ec2_transit_gateway_route.static["shared-services-from-prod"].transit_gateway_route_table_id == var.route_table_ids["prod"] && aws_ec2_transit_gateway_route.static["shared-services-from-prod"].destination_cidr_block == "10.20.0.0/16"
    error_message = "A targeted route is not a blackhole and lands in the named domain's table."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["ipv6-block"].blackhole && aws_ec2_transit_gateway_route.static["ipv6-block"].destination_cidr_block == "2001:db8::/32"
    error_message = "IPv6 prefixes are supported as blackhole routes."
  }
}

run "allows_a_blackhole_in_the_prod_table_for_a_non_prod_prefix" {
  command = plan

  variables {
    static_routes = {
      prod-blocks-nonprod-space = {
        route_table_domain     = "prod"
        destination_cidr_block = "10.128.0.0/9"
        blackhole              = true
      }
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["prod-blocks-nonprod-space"].blackhole
    error_message = "Blackholes tighten isolation and are always allowed."
  }
}

run "an_empty_propagation_entry_means_no_propagated_routes" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = []
      non-prod   = []
      shared     = []
      inspection = []
      on-prem    = []
    }
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_propagation.approved) == 0 && length(aws_ec2_transit_gateway_route_table_association.approved) == 3
    error_message = "An empty entry declares the domain and grants nothing; attachments are still associated."
  }
}

run "several_attachments_of_one_account_share_its_domain" {
  command = plan

  variables {
    attachments = {
      prod-app-a = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "111122223333"
      }
      prod-app-b = {
        attachment_id = "tgw-attach-0123abce"
        account_id    = "111122223333"
      }
    }
  }

  assert {
    condition     = output.attachment_domains == { prod-app-a = "prod", prod-app-b = "prod" } && length(aws_ec2_transit_gateway_route_table_propagation.approved) == 6
    error_message = "Every attachment of an approved account takes that account's one domain and its propagation entries."
  }
}

run "an_empty_catalog_creates_only_the_policy_record" {
  command = plan

  variables {
    attachments   = {}
    static_routes = {}
  }

  assert {
    condition = (
      length(aws_ec2_transit_gateway_vpc_attachment_accepter.approved) == 0 &&
      length(aws_ec2_transit_gateway_route_table_association.approved) == 0 &&
      length(aws_ec2_transit_gateway_route_table_propagation.approved) == 0 &&
      length(aws_ec2_transit_gateway_route.static) == 0 &&
      output.attachment_domains == {}
    )
    error_message = "With no attachments and no routes the module creates no TGW resources."
  }
}
