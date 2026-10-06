mock_provider "aws" {}

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
    propagation_ids           = []
  }

  routes = {
    private-a = {
      route_table_id         = "rtb-0123abcd"
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}

run "rejects_empty_routes" {
  command = plan
  variables { routes = {} }
  expect_failures = [var.routes]
}

run "rejects_noncanonical_destination" {
  command = plan
  variables {
    routes = {
      private-a = {
        route_table_id         = "rtb-0123abcd"
        destination_cidr_block = "10.0.0.1/8"
      }
    }
  }
  expect_failures = [var.routes]
}

run "rejects_duplicate_table_and_destination" {
  command = plan
  variables {
    routes = {
      private-a = { route_table_id = "rtb-0123abcd", destination_cidr_block = "10.0.0.0/8" }
      private-b = { route_table_id = "rtb-0123abcd", destination_cidr_block = "10.0.0.0/8" }
    }
  }
  expect_failures = [var.routes]
}
