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

# One failing run per variable validation, each overriding only what it tests.

run "rejects_an_empty_route_table_catalog" {
  command = plan

  variables {
    route_table_ids          = {}
    approved_account_domains = {}
    attachments              = {}
    propagation_matrix       = {}
    static_routes            = {}
  }

  expect_failures = [var.route_table_ids]
}

run "rejects_a_malformed_route_table_id" {
  command = plan

  variables {
    route_table_ids = {
      prod       = "rtb-0123abcd"
      non-prod   = "tgw-rtb-4567cdef"
      shared     = "tgw-rtb-89abcdef"
      inspection = "tgw-rtb-01234567"
      on-prem    = "tgw-rtb-89abcd01"
    }
  }

  expect_failures = [var.route_table_ids]
}

run "rejects_two_domains_that_share_one_route_table" {
  command = plan

  variables {
    route_table_ids = {
      prod       = "tgw-rtb-0123abcd"
      non-prod   = "tgw-rtb-0123abcd"
      shared     = "tgw-rtb-89abcdef"
      inspection = "tgw-rtb-01234567"
      on-prem    = "tgw-rtb-89abcd01"
    }
  }

  expect_failures = [var.route_table_ids]
}

run "rejects_an_account_key_that_is_not_twelve_digits" {
  command = plan

  variables {
    approved_account_domains = {
      "1111222233" = "prod"
    }
  }

  expect_failures = [var.approved_account_domains]
}

run "rejects_a_catalog_key_the_spoke_could_not_have_used" {
  command = plan

  variables {
    attachments = {
      "Prod-App" = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "111122223333"
      }
    }
  }

  expect_failures = [var.attachments]
}

run "rejects_a_malformed_attachment_id" {
  command = plan

  variables {
    attachments = {
      prod-app = {
        attachment_id = "attach-0123abcd"
        account_id    = "111122223333"
      }
    }
  }

  expect_failures = [var.attachments]
}

run "rejects_a_malformed_expected_owner_account" {
  command = plan

  variables {
    attachments = {
      prod-app = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "1111222233"
      }
    }
  }

  expect_failures = [var.attachments]
}

run "rejects_an_attachment_id_listed_twice" {
  command = plan

  variables {
    attachments = {
      prod-app-a = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "111122223333"
      }
      prod-app-b = {
        attachment_id = "tgw-attach-0123abcd"
        account_id    = "111122223333"
      }
    }
  }

  expect_failures = [var.attachments]
}

run "rejects_a_static_route_without_a_cidr" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "not-a-cidr"
        blackhole              = true
      }
    }
  }

  expect_failures = [var.static_routes]
}

run "rejects_a_static_route_cidr_with_host_bits_set" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.0.0.1/8"
        blackhole              = true
      }
    }
  }

  expect_failures = [var.static_routes]
}

run "rejects_a_blackhole_route_that_also_names_a_target" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
        target_attachment_key  = "prod-app"
      }
    }
  }

  expect_failures = [var.static_routes]
}

run "rejects_a_forwarding_route_without_a_target" {
  command = plan

  variables {
    static_routes = {
      bad = {
        route_table_domain     = "shared"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = false
      }
    }
  }

  expect_failures = [var.static_routes]
}

run "rejects_the_same_prefix_twice_in_one_table" {
  command = plan

  variables {
    static_routes = {
      first = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
      }
      second = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
      }
    }
  }

  expect_failures = [var.static_routes]
}

run "accepts_the_same_prefix_in_different_tables" {
  command = plan

  variables {
    static_routes = {
      first = {
        route_table_domain     = "non-prod"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
      }
      second = {
        route_table_domain     = "on-prem"
        destination_cidr_block = "10.0.0.0/8"
        blackhole              = true
      }
    }
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.static) == 2
    error_message = "One prefix may be blackholed in several tables."
  }
}

run "rejects_a_reserved_tag_prefix" {
  command = plan

  variables {
    tags = {
      "aws:cloudformation:stack-name" = "x"
    }
  }

  expect_failures = [var.tags]
}
