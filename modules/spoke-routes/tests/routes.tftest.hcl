mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
      user_id    = "111122223333"
    }
  }

  mock_resource "aws_route" {
    defaults = {
      id = "r-rtb0123abcd10"
    }
  }
}

variables {
  attachment = {
    id             = "tgw-attach-0123abcd"
    attachment_key = "prod-app-use2"
  }

  network_acceptance_receipt = {
    contract_version          = 1
    ready                     = true
    attachment_key            = "prod-app-use2"
    attachment_id             = "tgw-attach-0123abcd"
    transit_gateway_id        = "tgw-0123abcd"
    vpc_owner_id              = "111122223333"
    route_domain              = "prod"
    associated_route_table_id = "tgw-rtb-0123abcd"
    association_id            = "tgw-rtb-0123abcd_tgw-attach-0123abcd"
    propagation_ids           = ["tgw-rtb-0123abcd_tgw-attach-0123abcd"]
  }

  routes = {
    private-a = {
      route_table_id         = "rtb-0123abcd"
      destination_cidr_block = "10.0.0.0/8"
    }
    private-b = {
      route_table_id         = "rtb-4567cdef"
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}

run "creates_routes_after_network_acceptance" {
  command = apply

  assert {
    condition     = length(aws_route.transit_gateway) == 2 && alltrue([for route in aws_route.transit_gateway : route.transit_gateway_id == "tgw-0123abcd"])
    error_message = "All declared spoke routes must target the receipt's verified Transit Gateway."
  }

  assert {
    condition     = output.routes["private-a"].attachment_id == "tgw-attach-0123abcd" && output.routes["private-a"].route_domain == "prod"
    error_message = "Route outputs must retain the Network-account authorization identity."
  }
}
