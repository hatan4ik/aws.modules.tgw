# The hub reads partition, region, and account only to build the KMS and IAM
# policies. The mock pins them so those documents can be asserted exactly.
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

# The flow-log record format and the metric filters are the part of this module
# a mock provider cannot validate against AWS, so they are pinned to the AWS
# Transit Gateway flow-log reference here. v0.2.0 used the VPC flow-log names
# (transit-gateway-id, action) that CreateFlowLogs rejects for a Transit
# Gateway, and a filter on `action = REJECT` that could never match.

run "uses_only_documented_transit_gateway_flow_log_fields" {
  command = plan

  assert {
    # Every field in the AWS "Transit Gateway Flow Log records: Available
    # fields" table (docs.aws.amazon.com/vpc/latest/tgw/tgw-flow-logs.html).
    condition = alltrue([
      for match in regexall("[$][{]([a-z0-9-]+)[}]", aws_flow_log.transit_gateway.log_format) :
      contains([
        "version", "resource-type", "account-id", "tgw-id", "tgw-attachment-id",
        "tgw-src-vpc-account-id", "tgw-dst-vpc-account-id", "tgw-src-vpc-id", "tgw-dst-vpc-id",
        "tgw-src-subnet-id", "tgw-dst-subnet-id", "tgw-src-eni", "tgw-dst-eni",
        "tgw-src-az-id", "tgw-dst-az-id", "tgw-pair-attachment-id",
        "srcaddr", "dstaddr", "srcport", "dstport", "protocol", "packets", "bytes",
        "start", "end", "log-status", "type",
        "packets-lost-no-route", "packets-lost-blackhole", "packets-lost-mtu-exceeded", "packets-lost-ttl-expired",
        "tcp-flags", "region", "flow-direction", "pkt-src-aws-service", "pkt-dst-aws-service",
      ], match[0])
    ])
    error_message = "Every field in the flow-log format must be a documented Transit Gateway flow-log field."
  }

  assert {
    condition     = length(regexall("[$][{]([a-z0-9-]+)[}]", aws_flow_log.transit_gateway.log_format)) == 24
    error_message = "The record has the 24 fields the metric filters and the runbook expect."
  }

  assert {
    condition     = !strcontains(aws_flow_log.transit_gateway.log_format, "transit-gateway") && !strcontains(aws_flow_log.transit_gateway.log_format, "$${action}")
    error_message = "The VPC flow-log field names transit-gateway-id, transit-gateway-attachment-id, and action do not exist for Transit Gateway flow logs."
  }

  assert {
    condition     = startswith(aws_flow_log.transit_gateway.log_format, "$${version} $${resource-type} $${account-id} $${tgw-id} $${tgw-attachment-id} ")
    error_message = "The record starts with the version, the resource type, the owner, and the TGW and attachment IDs."
  }

  assert {
    condition     = endswith(aws_flow_log.transit_gateway.log_format, " $${packets-lost-no-route} $${packets-lost-blackhole}")
    error_message = "The two drop counters must be the last two fields; the metric filter patterns name them by position."
  }
}

run "counts_a_record_as_rejected_when_either_drop_counter_is_positive" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_metric_filter.rejected_traffic.pattern == "[..., packets_lost_no_route > 0, packets_lost_blackhole]"
    error_message = "One filter matches records that lost packets for lack of a route (the deny-by-default case)."
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.blackholed_traffic.pattern == "[..., packets_lost_no_route, packets_lost_blackhole > 0]"
    error_message = "The other filter matches records that lost packets to a blackhole route."
  }

  assert {
    condition     = !strcontains(aws_cloudwatch_log_metric_filter.rejected_traffic.pattern, "REJECT") && !strcontains(aws_cloudwatch_log_metric_filter.blackholed_traffic.pattern, "REJECT")
    error_message = "Transit Gateway records have no action field, so a filter on REJECT could never match."
  }
}

run "keeps_the_flow_log_format_stable_across_hub_names" {
  command = plan

  variables {
    name = "other-hub"
  }

  assert {
    condition     = aws_flow_log.transit_gateway.log_format == "$${version} $${resource-type} $${account-id} $${tgw-id} $${tgw-attachment-id} $${tgw-src-vpc-account-id} $${tgw-dst-vpc-account-id} $${tgw-src-vpc-id} $${tgw-dst-vpc-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${log-status} $${flow-direction} $${packets-lost-mtu-exceeded} $${packets-lost-ttl-expired} $${packets-lost-no-route} $${packets-lost-blackhole}"
    error_message = "The record format is a fixed contract with the metric filters and the SRE runbook, independent of the hub name."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.name == "/aws/tgw/other-hub/flow-logs" && aws_iam_role.flow_logs.name == "other-hub-tgw-flow-logs"
    error_message = "Names derive from the hub name."
  }
}

run "extends_retention_within_the_supported_periods" {
  command = plan

  variables {
    flow_log_retention_in_days = 3653
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.retention_in_days == 3653
    error_message = "A longer supported retention period is honoured."
  }
}

run "notifies_the_supplied_alarm_actions_at_a_custom_threshold" {
  command = plan

  variables {
    rejected_traffic_alarm_threshold = 25
    rejected_traffic_alarm_actions = [
      "arn:aws:sns:us-east-1:123456789012:network-sre",
      "arn:aws:sns:us-east-1:123456789012:network-oncall",
    ]
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.rejected_traffic.threshold == 25
    error_message = "The alarm threshold is the caller's."
  }

  assert {
    condition     = toset(aws_cloudwatch_metric_alarm.rejected_traffic.alarm_actions) == toset(["arn:aws:sns:us-east-1:123456789012:network-sre", "arn:aws:sns:us-east-1:123456789012:network-oncall"])
    error_message = "Every supplied action is wired to the alarm and none is added."
  }

  assert {
    condition     = toset(aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.alarm_actions) == toset(["arn:aws:sns:us-east-1:123456789012:network-sre", "arn:aws:sns:us-east-1:123456789012:network-oncall"])
    error_message = "The delivery-stopped alarm notifies the same actions: losing the evidence matters to the same people."
  }
}

run "accepts_an_automate_action_without_an_account" {
  command = plan

  variables {
    rejected_traffic_alarm_actions = ["arn:aws:automate:us-east-1:ec2:reboot"]
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.rejected_traffic.alarm_actions) == 1
    error_message = "Alarm actions such as arn:aws:automate:... carry no account ID and are valid."
  }
}
