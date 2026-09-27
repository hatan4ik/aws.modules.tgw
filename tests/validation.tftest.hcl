# One failing run per variable validation, plus the accepted edges, each
# overriding only what it tests. Every input is checked at plan time so a bad
# value never reaches the provider.
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

# name

run "accepts_the_shortest_and_the_longest_name" {
  command = plan

  variables {
    name = "abc"
  }

  assert {
    condition     = aws_iam_role.flow_logs.name == "abc-tgw-flow-logs"
    error_message = "A 3-character name is valid."
  }
}

run "accepts_a_fifty_character_name_whose_flow_log_role_fits_iam" {
  command = plan

  variables {
    name = "a-name-of-exactly-fifty-characters-0123456789-abcd"
  }

  assert {
    condition     = length(var.name) == 50 && length(aws_iam_role.flow_logs.name) == 64
    error_message = "A 50-character name yields a 64-character role name, the IAM maximum."
  }
}

run "rejects_a_name_whose_flow_log_role_would_exceed_the_iam_limit" {
  command = plan

  variables {
    name = "a-name-of-exactly-fifty-characters-0123456789-abcde"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_uppercase_letters" {
  command = plan

  variables {
    name = "Test-Regional-TGW"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_that_starts_with_a_digit" {
  command = plan

  variables {
    name = "1-regional-tgw"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_that_is_too_short" {
  command = plan

  variables {
    name = "ab"
  }

  expect_failures = [var.name]
}

# amazon_side_asn

run "accepts_the_edges_of_both_private_asn_ranges" {
  command = plan

  variables {
    amazon_side_asn = 65534
  }

  assert {
    condition     = tonumber(aws_ec2_transit_gateway.this.amazon_side_asn) == 65534
    error_message = "65534 is the top of the 16-bit private range."
  }
}

run "accepts_the_lowest_thirty_two_bit_private_asn" {
  command = plan

  variables {
    amazon_side_asn = 4200000000
  }

  assert {
    condition     = tonumber(aws_ec2_transit_gateway.this.amazon_side_asn) == 4200000000
    error_message = "4200000000 is the bottom of the 32-bit private range."
  }
}

run "accepts_the_highest_thirty_two_bit_private_asn" {
  command = plan

  variables {
    amazon_side_asn = 4294967294
  }

  assert {
    condition     = tonumber(aws_ec2_transit_gateway.this.amazon_side_asn) == 4294967294
    error_message = "4294967294 is the top of the 32-bit private range."
  }
}

run "rejects_public_asn" {
  command = plan

  variables {
    amazon_side_asn = 64496
  }

  expect_failures = [var.amazon_side_asn]
}

run "rejects_the_reserved_asn_above_the_sixteen_bit_range" {
  command = plan

  variables {
    amazon_side_asn = 65535
  }

  expect_failures = [var.amazon_side_asn]
}

run "rejects_an_asn_between_the_two_private_ranges" {
  command = plan

  variables {
    amazon_side_asn = 4199999999
  }

  expect_failures = [var.amazon_side_asn]
}

run "rejects_the_reserved_asn_above_the_thirty_two_bit_range" {
  command = plan

  variables {
    amazon_side_asn = 4294967295
  }

  expect_failures = [var.amazon_side_asn]
}

run "rejects_a_fractional_asn" {
  command = plan

  variables {
    amazon_side_asn = 64512.5
  }

  expect_failures = [var.amazon_side_asn]
}

# route_domains

run "accepts_custom_route_domains" {
  command = plan

  variables {
    route_domains = ["prod", "non-prod", "shared", "inspection", "on-prem", "quarantine"]
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.domain) == 6 && contains(keys(aws_ec2_transit_gateway_route_table.domain), "quarantine")
    error_message = "A domain beyond the five ADR domains gets its own route table, and the ADR domains stay."
  }
}

run "rejects_no_route_domains" {
  command = plan

  variables {
    route_domains = []
  }

  expect_failures = [var.route_domains]
}

run "rejects_an_uppercase_route_domain" {
  command = plan

  variables {
    route_domains = ["Prod", "non-prod", "shared", "inspection", "on-prem"]
  }

  expect_failures = [var.route_domains]
}

run "rejects_a_one_character_route_domain" {
  command = plan

  variables {
    route_domains = ["p", "non-prod", "shared", "inspection", "on-prem"]
  }

  expect_failures = [var.route_domains]
}

run "rejects_a_route_domain_that_is_too_long" {
  command = plan

  variables {
    route_domains = ["a-domain-name-of-thirty-two-chars", "non-prod", "shared", "inspection", "on-prem"]
  }

  expect_failures = [var.route_domains]
}

# flow_log_retention_in_days

run "rejects_retention_below_one_year" {
  command = plan

  variables {
    flow_log_retention_in_days = 364
  }

  expect_failures = [var.flow_log_retention_in_days]
}

run "rejects_an_unsupported_retention_period" {
  command = plan

  variables {
    flow_log_retention_in_days = 366
  }

  expect_failures = [var.flow_log_retention_in_days]
}

run "rejects_short_supported_retention" {
  command = plan

  variables {
    flow_log_retention_in_days = 90
  }

  expect_failures = [var.flow_log_retention_in_days]
}

# rejected_traffic_alarm_threshold

run "rejects_a_zero_alarm_threshold" {
  command = plan

  variables {
    rejected_traffic_alarm_threshold = 0
  }

  expect_failures = [var.rejected_traffic_alarm_threshold]
}

run "rejects_a_fractional_alarm_threshold" {
  command = plan

  variables {
    rejected_traffic_alarm_threshold = 1.5
  }

  expect_failures = [var.rejected_traffic_alarm_threshold]
}

# rejected_traffic_alarm_actions

run "rejects_an_alarm_action_that_is_not_an_arn" {
  command = plan

  variables {
    rejected_traffic_alarm_actions = ["network-sre"]
  }

  expect_failures = [var.rejected_traffic_alarm_actions]
}

run "accepts_five_alarm_actions" {
  command = plan

  variables {
    rejected_traffic_alarm_actions = [
      "arn:aws:sns:us-east-1:123456789012:a",
      "arn:aws:sns:us-east-1:123456789012:b",
      "arn:aws:sns:us-east-1:123456789012:c",
      "arn:aws:sns:us-east-1:123456789012:d",
      "arn:aws:sns:us-east-1:123456789012:e",
    ]
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.rejected_traffic.alarm_actions) == 5
    error_message = "CloudWatch allows five alarm actions."
  }
}

run "rejects_more_than_five_alarm_actions" {
  command = plan

  variables {
    rejected_traffic_alarm_actions = [
      "arn:aws:sns:us-east-1:123456789012:a",
      "arn:aws:sns:us-east-1:123456789012:b",
      "arn:aws:sns:us-east-1:123456789012:c",
      "arn:aws:sns:us-east-1:123456789012:d",
      "arn:aws:sns:us-east-1:123456789012:e",
      "arn:aws:sns:us-east-1:123456789012:f",
    ]
  }

  expect_failures = [var.rejected_traffic_alarm_actions]
}

# tags

run "rejects_a_reserved_tag_prefix" {
  command = plan

  variables {
    tags = {
      "aws:cloudformation:stack-name" = "x"
    }
  }

  expect_failures = [var.tags]
}
