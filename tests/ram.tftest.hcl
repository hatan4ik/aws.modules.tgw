# RAM sharing is restricted to approved principals: 12-digit account IDs or
# AWS Organizations organization/OU ARNs, never IAM users or roles, and never
# outside the organization. The deprecated ram_principal_arns input keeps
# working, with a check that says so.
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

run "accepts_an_individual_aws_account_for_ram" {
  command = plan

  variables {
    ram_principals = ["111122223333"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1
    error_message = "A TGW RAM share must accept an approved 12-digit AWS account ID."
  }

  assert {
    condition     = aws_ram_principal_association.approved_principal["111122223333"].principal == "111122223333"
    error_message = "The association is keyed by, and shares with, the account ID."
  }

  assert {
    condition     = aws_ram_resource_share.this.allow_external_principals == false
    error_message = "Sharing with an account never enables principals outside the organization."
  }
}

run "accepts_an_organization_arn" {
  command = plan

  variables {
    ram_principals = ["arn:aws:organizations::111122223333:organization/o-example"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1 && aws_ram_principal_association.approved_principal["arn:aws:organizations::111122223333:organization/o-example"].principal == "arn:aws:organizations::111122223333:organization/o-example"
    error_message = "A TGW RAM share must accept an AWS Organizations organization ARN."
  }
}

run "accepts_an_organizational_unit_arn" {
  command = plan

  variables {
    ram_principals = ["arn:aws:organizations::111122223333:ou/o-example/ou-ab12-cdef3456"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1
    error_message = "A TGW RAM share must accept an AWS Organizations OU ARN."
  }
}

run "accepts_a_mix_of_accounts_and_organization_principals" {
  command = plan

  variables {
    ram_principals = [
      "111122223333",
      "444455556666",
      "arn:aws:organizations::111122223333:ou/o-example/ou-ab12-cdef3456",
    ]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 3
    error_message = "Each approved principal gets exactly one association."
  }
}

run "accepts_a_government_partition_organization_arn" {
  command = plan

  variables {
    ram_principals = ["arn:aws-us-gov:organizations::111122223333:organization/o-example"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1
    error_message = "Organization ARNs in other partitions are structurally valid."
  }
}

run "an_empty_set_shares_with_nobody" {
  command = plan

  variables {
    ram_principals = []
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 0
    error_message = "An explicit empty set is valid and creates no principal association; the owner's own VPCs need no share."
  }
}

run "rejects_iam_principal_for_tgw_ram" {
  command = plan

  variables {
    ram_principals = ["arn:aws:iam::111122223333:role/not-a-tgw-consumer"]
  }

  expect_failures = [var.ram_principals]
}

run "rejects_an_account_id_that_is_not_twelve_digits" {
  command = plan

  variables {
    ram_principals = ["11112222333"]
  }

  expect_failures = [var.ram_principals]
}

run "rejects_an_organization_arn_that_is_not_an_organization" {
  command = plan

  variables {
    ram_principals = ["arn:aws:organizations::111122223333:account/o-example/111122223333"]
  }

  expect_failures = [var.ram_principals]
}

run "rejects_a_malformed_organizational_unit_arn" {
  command = plan

  variables {
    ram_principals = ["arn:aws:organizations::111122223333:ou/o-example"]
  }

  expect_failures = [var.ram_principals]
}

run "rejects_a_wildcard_principal" {
  command = plan

  variables {
    ram_principals = ["*"]
  }

  expect_failures = [var.ram_principals]
}

# Deprecated compatibility input.

run "still_honours_the_deprecated_ram_principal_arns" {
  command = plan

  variables {
    ram_principal_arns = ["arn:aws:organizations::111122223333:organization/o-example"]
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 1
    error_message = "The deprecated input keeps sharing until v2 removes it."
  }

  expect_failures = [check.deprecated_ram_principal_arns]
}

run "rejects_an_iam_principal_in_the_deprecated_input" {
  command = plan

  variables {
    ram_principal_arns = ["arn:aws:iam::111122223333:role/not-a-tgw-consumer"]
  }

  expect_failures = [var.ram_principal_arns]
}

run "prefers_ram_principals_and_warns_that_the_deprecated_input_is_ignored" {
  command = plan

  variables {
    ram_principals     = ["111122223333"]
    ram_principal_arns = ["arn:aws:organizations::111122223333:organization/o-example"]
  }

  assert {
    condition     = toset(keys(aws_ram_principal_association.approved_principal)) == toset(["111122223333"])
    error_message = "ram_principals wins; principals listed only in the deprecated input are not shared."
  }

  expect_failures = [
    check.deprecated_ram_principal_arns,
    check.ram_principal_arns_ignored,
  ]
}
