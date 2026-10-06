mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
      user_id    = "111122223333"
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
  }
}

run "rejects_unready_receipt" {
  command = plan

  variables {
    network_acceptance_receipt = {
      contract_version          = 1
      ready                     = false
      attachment_key            = "prod-app-use2"
      attachment_id             = "tgw-attach-0123abcd"
      transit_gateway_id        = "tgw-0123abcd"
      vpc_owner_id              = "111122223333"
      route_domain              = "prod"
      associated_route_table_id = "tgw-rtb-0123abcd"
      association_id            = "tgw-rtb-0123abcd_tgw-attach-0123abcd"
      propagation_ids           = []
    }
  }

  expect_failures = [terraform_data.route_activation_barrier]
}

run "rejects_mismatched_attachment" {
  command = plan

  variables {
    attachment = {
      id             = "tgw-attach-4567cdef"
      attachment_key = "prod-app-use2"
    }
  }

  expect_failures = [terraform_data.route_activation_barrier]
}

run "rejects_receipt_for_another_account" {
  command = plan

  variables {
    network_acceptance_receipt = {
      contract_version          = 1
      ready                     = true
      attachment_key            = "prod-app-use2"
      attachment_id             = "tgw-attach-0123abcd"
      transit_gateway_id        = "tgw-0123abcd"
      vpc_owner_id              = "444455556666"
      route_domain              = "prod"
      associated_route_table_id = "tgw-rtb-0123abcd"
      association_id            = "tgw-rtb-0123abcd_tgw-attach-0123abcd"
      propagation_ids           = ["tgw-rtb-0123abcd_tgw-attach-0123abcd"]
    }
  }

  expect_failures = [terraform_data.route_activation_barrier]
}

run "rejects_unsupported_contract_version" {
  command = plan

  variables {
    network_acceptance_receipt = {
      contract_version          = 2
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
  }

  expect_failures = [terraform_data.route_activation_barrier]
}
