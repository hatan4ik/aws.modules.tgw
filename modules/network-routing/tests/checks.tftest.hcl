# Advisory check blocks warn without blocking a plan, but a firing check fails a
# terraform test run unless it is listed in expect_failures. Every other test
# file uses the ADR 0003 domain names and so proves the check stays quiet on a
# correct catalog; this file proves it fires when the isolation guard would
# silently not apply.
mock_provider "aws" {}

variables {
  approved_account_domains = {}
  attachments              = {}
  static_routes            = {}
}

run "does_not_warn_when_both_isolation_domains_are_present" {
  command = plan

  variables {
    route_table_ids = {
      prod     = "tgw-rtb-0123abcd"
      non-prod = "tgw-rtb-4567cdef"
    }
    propagation_matrix = {}
  }

  assert {
    condition     = length(keys(var.route_table_ids)) == 2
    error_message = "A catalog with prod and non-prod raises no advisory check."
  }
}

run "warns_when_domains_use_names_the_isolation_guard_does_not_know" {
  command = plan

  variables {
    route_table_ids = {
      production = "tgw-rtb-0123abcd"
      nonprod    = "tgw-rtb-4567cdef"
    }
    # Propagating these into each other is exactly what ADR 0003 forbids, and
    # the precondition cannot see it under these names. The plan still succeeds;
    # only the check reports it.
    propagation_matrix = {
      production = ["production", "nonprod"]
      nonprod    = ["production", "nonprod"]
    }
  }

  expect_failures = [check.isolation_domains_present]
}

run "warns_when_only_one_isolation_domain_is_present" {
  command = plan

  variables {
    route_table_ids = {
      prod   = "tgw-rtb-0123abcd"
      shared = "tgw-rtb-4567cdef"
    }
    propagation_matrix = {}
  }

  expect_failures = [check.isolation_domains_present]
}
