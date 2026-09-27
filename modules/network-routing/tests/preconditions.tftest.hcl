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

# Cross-input rules live in preconditions on terraform_data.network_policy.
# Association, propagation, acceptance, and static routes all depend on it, so
# a failed rule creates nothing.

run "rejects_an_approved_domain_that_has_no_route_table" {
  command = plan

  variables {
    approved_account_domains = {
      "111122223333" = "staging"
      "444455556666" = "non-prod"
      "777788889999" = "shared"
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_an_attachment_from_an_unapproved_account" {
  command = plan

  variables {
    attachments = {
      stranger = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "999999999999"
      }
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_propagation_source_that_is_not_a_domain" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = ["prod", "shared", "on-prem"]
      non-prod   = ["non-prod", "shared"]
      shared     = ["prod", "non-prod", "shared"]
      inspection = ["inspection"]
      on-prem    = ["prod", "non-prod", "shared", "on-prem"]
      staging    = ["staging"]
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_propagation_destination_that_is_not_a_domain" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = ["prod", "staging"]
      non-prod   = ["non-prod", "shared"]
      shared     = ["prod", "non-prod", "shared"]
      inspection = ["inspection"]
      on-prem    = ["prod", "non-prod", "shared", "on-prem"]
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_domain_with_attachments_but_no_matrix_entry" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = ["prod", "shared", "on-prem"]
      non-prod   = ["non-prod", "shared"]
      inspection = ["inspection"]
      on-prem    = ["prod", "non-prod", "shared", "on-prem"]
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_static_route_in_an_unknown_domain" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "staging"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
      }
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_static_route_to_an_attachment_outside_the_catalog" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "shared"
        destination_cidr_block = "10.30.0.0/16"
        blackhole              = false
        target_attachment_key  = "ghost"
      }
    }
  }

  expect_failures = [terraform_data.network_policy]
}

# ADR 0003: the routing composition must reject direct prod <-> non-prod
# connectivity in either direction, by propagation or by static route.

run "rejects_prod_propagating_into_non_prod" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = ["prod", "non-prod"]
      non-prod   = ["non-prod", "shared"]
      shared     = ["prod", "non-prod", "shared"]
      inspection = ["inspection"]
      on-prem    = ["prod", "non-prod", "shared", "on-prem"]
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_non_prod_propagating_into_prod" {
  command = plan

  variables {
    propagation_matrix = {
      prod       = ["prod", "shared"]
      non-prod   = ["non-prod", "prod"]
      shared     = ["prod", "non-prod", "shared"]
      inspection = ["inspection"]
      on-prem    = ["prod", "non-prod", "shared", "on-prem"]
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_prod_table_route_to_a_non_prod_attachment" {
  command = plan

  variables {
    static_routes = {
      leak = {
        route_table_domain     = "prod"
        destination_cidr_block = "10.128.0.0/16"
        blackhole              = false
        target_attachment_key  = "nonprod-app"
      }
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "rejects_a_non_prod_table_route_to_a_prod_attachment" {
  command = plan

  variables {
    static_routes = {
      leak = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.10.0.0/16"
        blackhole              = false
        target_attachment_key  = "prod-app"
      }
    }
  }

  expect_failures = [terraform_data.network_policy]
}

run "allows_the_shared_domain_to_reach_both_prod_and_non_prod" {
  command = plan

  variables {
    static_routes = {
      shared-to-prod = {
        route_table_domain     = "shared"
        destination_cidr_block = "10.10.0.0/16"
        blackhole              = false
        target_attachment_key  = "prod-app"
      }
      shared-to-nonprod = {
        route_table_domain     = "shared"
        destination_cidr_block = "10.128.0.0/16"
        blackhole              = false
        target_attachment_key  = "nonprod-app"
      }
    }
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.static) == 2
    error_message = "The isolation rule concerns only the prod and non-prod pair; shared may reach both."
  }
}
