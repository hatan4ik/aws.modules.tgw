# Advisory check blocks warn without blocking a plan, but a firing check fails a
# terraform test run unless it is listed in expect_failures. The defaults and
# every other test file therefore prove that nothing fires on a correct call;
# this file proves each check does fire on the situation it describes.
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  name            = "test-regional-tgw"
  amazon_side_asn = 64512
}

run "route_domains_that_extend_the_adr_set_raise_no_warning" {
  command = plan

  variables {
    route_domains = ["prod", "non-prod", "shared", "inspection", "on-prem", "quarantine"]
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.domain) == 6
    error_message = "Extra domains are legitimate: the ADR names a minimum, not a closed set."
  }
}

run "warns_when_route_domains_omit_an_adr_domain" {
  command = plan

  variables {
    route_domains = ["prod", "non-prod", "shared", "inspection"]
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.domain) == 4
    error_message = "The hub is still created; the check only warns."
  }

  expect_failures = [check.route_domains_cover_adr_0003]
}

run "warns_when_the_hub_has_no_prod_or_non_prod_domain" {
  command = plan

  variables {
    route_domains = ["shared", "inspection", "on-prem"]
  }

  expect_failures = [check.route_domains_cover_adr_0003]
}

run "warns_that_the_deprecated_input_is_deprecated" {
  command = plan

  variables {
    ram_principal_arns = ["111122223333"]
  }

  expect_failures = [check.deprecated_ram_principal_arns]
}

run "does_not_warn_of_an_ignored_input_when_only_ram_principals_is_set" {
  command = plan

  variables {
    ram_principals = ["111122223333"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1
    error_message = "ram_principals alone raises no advisory check."
  }
}

run "warns_when_an_explicit_empty_ram_principals_hides_the_deprecated_input" {
  command = plan

  variables {
    ram_principals     = []
    ram_principal_arns = ["111122223333"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 0
    error_message = "An explicit empty ram_principals wins, so the deprecated input shares with nobody."
  }

  expect_failures = [
    check.deprecated_ram_principal_arns,
    check.ram_principal_arns_ignored,
  ]
}
