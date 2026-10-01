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

# ADR 0003: the hub is deny-by-default. Nothing is associated, propagated, or
# accepted unless the network account's routing composition says so.

run "disables_every_default_route_table_behaviour" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable" && aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "TGW default association and propagation must remain disabled, so no attachment lands in a default route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.auto_accept_shared_attachments == "disable"
    error_message = "Shared attachments must never be accepted automatically; the network account accepts and verifies each one."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.encryption_support == "enable" && aws_ec2_transit_gateway.this.dns_support == "enable"
    error_message = "The TGW must retain encryption support (ADR 0003) and DNS support."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.security_group_referencing_support == "disable" && aws_ec2_transit_gateway.this.multicast_support == "disable"
    error_message = "Security-group referencing and multicast stay off: the first bypasses account-owned policy, the second is invisible to flow logs."
  }

  assert {
    condition     = tonumber(aws_ec2_transit_gateway.this.amazon_side_asn) == 64512 && aws_ec2_transit_gateway.this.vpn_ecmp_support == "enable"
    error_message = "The Amazon-side ASN is the approved input and ECMP stays on for the VPN compositions."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.description == "Segmented regional transit gateway test-regional-tgw"
    error_message = "The TGW description must name the hub."
  }
}

run "creates_the_five_adr_route_domains_each_with_its_own_table" {
  command = plan

  assert {
    condition     = toset(keys(aws_ec2_transit_gateway_route_table.domain)) == toset(["prod", "non-prod", "shared", "inspection", "on-prem"])
    error_message = "A hub must have the five ADR-defined route domains by default."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route_table.domain["non-prod"].tags["RouteDomain"] == "non-prod" && aws_ec2_transit_gateway_route_table.domain["non-prod"].tags["Name"] == "test-regional-tgw-non-prod"
    error_message = "Every route table is tagged with its domain and named <hub>-<domain>."
  }

  assert {
    condition     = toset(keys(output.route_table_ids)) == toset(["prod", "non-prod", "shared", "inspection", "on-prem"])
    error_message = "route_table_ids must map every domain to its table for the network-routing module."
  }
}

run "shares_with_nobody_and_never_outside_the_organization_by_default" {
  command = plan

  assert {
    condition     = aws_ram_resource_share.this.allow_external_principals == false
    error_message = "The RAM share must never allow principals outside the AWS Organization."
  }

  assert {
    condition     = length(aws_ram_principal_association.approved_principal) == 0
    error_message = "No principal is shared with until one is approved."
  }

  assert {
    condition     = aws_ram_resource_share.this.name == "test-regional-tgw-attachment-share"
    error_message = "The share is named <hub>-attachment-share."
  }
}

run "tags_every_resource_with_computed_identity" {
  command = plan

  variables {
    tags = {
      CostCenter = "network"
      Name       = "spoofed"
      Component  = "spoofed"
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.tags["Name"] == "test-regional-tgw" && aws_ec2_transit_gateway.this.tags["Component"] == "transit-gateway-hub" && aws_ec2_transit_gateway.this.tags["CostCenter"] == "network"
    error_message = "Name and Component are computed and cannot be overridden; other caller tags are kept."
  }

  assert {
    condition     = aws_ram_resource_share.this.tags["Component"] == "transit-gateway-hub" && aws_cloudwatch_log_group.flow_logs.tags["CostCenter"] == "network" && aws_cloudwatch_metric_alarm.rejected_traffic.tags["CostCenter"] == "network"
    error_message = "Caller tags reach the share, the log group, and the alarm."
  }
}

run "encrypts_flow_logs_with_a_rotating_key_that_only_this_log_group_can_use" {
  command = plan

  assert {
    condition     = aws_kms_key.flow_logs.enable_key_rotation && aws_kms_key.flow_logs.deletion_window_in_days == 30
    error_message = "The flow-log key rotates and keeps the full 30-day deletion window."
  }

  assert {
    condition     = aws_kms_key.flow_logs.tags["DataClass"] == "network-observability" && aws_kms_key.flow_logs.tags["Name"] == "test-regional-tgw-tgw-flow-logs" && aws_kms_alias.flow_logs.name == "alias/test-regional-tgw-tgw-flow-logs"
    error_message = "The key is named, aliased, and classified like the platform's other flow-log keys."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.flow_logs.policy).Statement[0].Sid == "AllowAccountRootAdministration" &&
      jsondecode(aws_kms_key.flow_logs.policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:root" &&
      jsondecode(aws_kms_key.flow_logs.policy).Statement[0].Action == "kms:*"
    )
    error_message = "The key policy keeps account administration through the account root."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.flow_logs.policy).Statement[1].Principal.Service == "logs.us-east-1.amazonaws.com" &&
      jsondecode(aws_kms_key.flow_logs.policy).Statement[1].Condition.ArnEquals["kms:EncryptionContext:aws:logs:arn"] == "arn:aws:logs:us-east-1:123456789012:log-group:/aws/tgw/test-regional-tgw/flow-logs" &&
      toset(jsondecode(aws_kms_key.flow_logs.policy).Statement[1].Action) == toset(["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"])
    )
    error_message = "CloudWatch Logs may use the key only in the encryption context of this hub's log group."
  }

  assert {
    condition     = length(jsondecode(aws_kms_key.flow_logs.policy).Statement) == 2 && alltrue([for statement in jsondecode(aws_kms_key.flow_logs.policy).Statement : statement.Effect == "Allow" && try(statement.Principal, "") != "*"])
    error_message = "The key policy has exactly two allow statements and no wildcard principal."
  }
}

run "retains_flow_logs_for_a_year_in_an_encrypted_log_group" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.name == "/aws/tgw/test-regional-tgw/flow-logs" && aws_cloudwatch_log_group.flow_logs.retention_in_days == 365
    error_message = "Network evidence is retained for at least one year in /aws/tgw/<hub>/flow-logs."
  }

  assert {
    condition     = output.flow_logs.log_group_name == "/aws/tgw/test-regional-tgw/flow-logs"
    error_message = "The flow_logs output reports the log group name."
  }
}

run "lets_only_the_flow_log_service_of_this_account_assume_the_delivery_role" {
  command = plan

  assert {
    condition = (
      aws_iam_role.flow_logs.name == "test-regional-tgw-tgw-flow-logs" &&
      jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Principal.Service == "vpc-flow-logs.amazonaws.com" &&
      jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    )
    error_message = "Only the flow-log service may assume the delivery role."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012" &&
      jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:ec2:us-east-1:123456789012:vpc-flow-log/*"
    )
    error_message = "The trust policy must guard against the confused deputy with aws:SourceAccount and aws:SourceArn."
  }

  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.flow_logs_delivery.policy).Statement[0].Action) == toset(["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]) &&
      jsondecode(aws_iam_role_policy.flow_logs_delivery.policy).Statement[0].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/aws/tgw/test-regional-tgw/flow-logs:*" &&
      length(jsondecode(aws_iam_role_policy.flow_logs_delivery.policy).Statement) == 1
    )
    error_message = "The delivery role may write only to this hub's log group and nothing else."
  }

  assert {
    condition     = aws_iam_role_policy.flow_logs_delivery.name == "test-regional-tgw-tgw-flow-logs-delivery"
    error_message = "The delivery policy is named <role>-delivery."
  }
}

run "records_all_transit_gateway_traffic_at_one_minute_aggregation" {
  command = plan

  assert {
    condition     = aws_flow_log.transit_gateway.log_destination_type == "cloud-watch-logs" && aws_flow_log.transit_gateway.max_aggregation_interval == 60
    error_message = "Transit Gateway flow logs go to CloudWatch Logs at the one-minute interval AWS requires."
  }

  assert {
    condition     = aws_flow_log.transit_gateway.traffic_type == null
    error_message = "AWS rejects traffic_type for Transit Gateway flow logs; the module must not set it."
  }

  assert {
    condition     = aws_flow_log.transit_gateway.tags["Name"] == "test-regional-tgw-tgw-all-traffic"
    error_message = "The flow log is named <hub>-tgw-all-traffic."
  }
}

run "wires_the_rejected_traffic_alarm_to_both_drop_filters" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_metric_filter.rejected_traffic.name == "test-regional-tgw-tgw-rejected-traffic" && aws_cloudwatch_log_metric_filter.blackholed_traffic.name == "test-regional-tgw-tgw-blackholed-traffic"
    error_message = "Each drop counter has its own named metric filter."
  }

  assert {
    condition = (
      aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].name == "TransitGatewayRejectedTraffic" &&
      aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].namespace == "Platform/TransitGateway" &&
      aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].value == "1" &&
      aws_cloudwatch_log_metric_filter.blackholed_traffic.metric_transformation[0].name == "TransitGatewayRejectedTraffic" &&
      aws_cloudwatch_log_metric_filter.blackholed_traffic.metric_transformation[0].namespace == "Platform/TransitGateway" &&
      aws_cloudwatch_log_metric_filter.blackholed_traffic.metric_transformation[0].value == "1"
    )
    error_message = "Both filters count one per matching record into the same Platform/TransitGateway metric."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.rejected_traffic.metric_name == aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].name &&
      aws_cloudwatch_metric_alarm.rejected_traffic.namespace == aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].namespace &&
      aws_cloudwatch_metric_alarm.rejected_traffic.metric_name == aws_cloudwatch_log_metric_filter.blackholed_traffic.metric_transformation[0].name
    )
    error_message = "The alarm must read the metric both filters write."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.rejected_traffic.alarm_name == "test-regional-tgw-tgw-rejected-traffic" &&
      aws_cloudwatch_metric_alarm.rejected_traffic.comparison_operator == "GreaterThanOrEqualToThreshold" &&
      aws_cloudwatch_metric_alarm.rejected_traffic.threshold == 1 &&
      aws_cloudwatch_metric_alarm.rejected_traffic.period == 300 &&
      aws_cloudwatch_metric_alarm.rejected_traffic.evaluation_periods == 1 &&
      aws_cloudwatch_metric_alarm.rejected_traffic.statistic == "Sum" &&
      aws_cloudwatch_metric_alarm.rejected_traffic.treat_missing_data == "notBreaching"
    )
    error_message = "The alarm sums rejected records over five minutes, fires on one, and does not fire on silence."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.rejected_traffic.alarm_actions) == 0
    error_message = "No alarm action is invented; callers supply their own."
  }
}

# The rejected-traffic alarm is quiet on silence, so it cannot see delivery
# stop. The heartbeat must read the log group's own ingestion metric and treat
# silence as a failure.
run "alarms_when_flow_log_delivery_stops" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.alarm_name == "test-regional-tgw-tgw-flow-log-delivery-stopped" &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.namespace == "AWS/Logs" &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.metric_name == "IncomingLogEvents" &&
      length(aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.dimensions) == 1 &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.dimensions["LogGroupName"] == "/aws/tgw/test-regional-tgw/flow-logs"
    )
    error_message = "The heartbeat reads IncomingLogEvents of this hub's flow-log group."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.comparison_operator == "LessThanThreshold" &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.threshold == 1 &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.statistic == "Sum" &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.period == 3600 &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.evaluation_periods == 1 &&
      aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.treat_missing_data == "breaching"
    )
    error_message = "An hour with no records alarms, and missing data (no records at all) counts as breaching."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.alarm_actions) == 0 && aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.tags["Component"] == "transit-gateway-hub"
    error_message = "No alarm action is invented, and the alarm carries the hub tags."
  }
}

run "passes_every_advisory_check_with_the_defaults" {
  command = plan

  assert {
    condition     = length(var.ram_principal_arns) == 0 && var.ram_principals == null
    error_message = "The default call sets neither RAM input, so no advisory check may fire (a firing check fails this run)."
  }
}
