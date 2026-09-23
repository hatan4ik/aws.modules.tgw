mock_provider "aws" {}

variables {
  route_table_ids = {
    prod       = "tgw-rtb-0123abcd"
    non-prod   = "tgw-rtb-4567cdef"
    shared     = "tgw-rtb-89abcdef"
    inspection = "tgw-rtb-01234567"
    on-prem    = "tgw-rtb-89abcdef"
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

  # Explicitly omit prod -> non-prod and non-prod -> prod. The test below
  # proves a future matrix edit cannot leak that route without changing policy.
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
    condition     = aws_ec2_transit_gateway_route_table_association.approved["prod-app"].transit_gateway_route_table_id == var.route_table_ids["prod"]
    error_message = "The network account must associate the production attachment to the production route table."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_propagation.approved) == 8
    error_message = "Only the approved propagation matrix may create propagated routes."
  }

  assert {
    condition     = !contains(keys(aws_ec2_transit_gateway_route_table_propagation.approved), "prod-app:non-prod") && !contains(keys(aws_ec2_transit_gateway_route_table_propagation.approved), "nonprod-app:prod")
    error_message = "The policy must not leak production and non-production routes."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.static["nonprod-private-block"].blackhole
    error_message = "Explicit forbidden prefixes must remain blackhole routes."
  }
}
