# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Nothing is hard-coded: the setup module generates a unique hub
# name, the module creates ONE hub with its defaults and no attachments and no
# shared principals, the results are asserted against the real API, and
# everything is destroyed at the end of the file.
#
# This is the only test that proves AWS accepts what a mock provider cannot
# check: the Transit Gateway flow-log record format, the flow-log role's trust
# policy with its aws:SourceAccount and aws:SourceArn conditions, and the
# metric-filter patterns. It is deliberately a single, short-lived apply. A
# Transit Gateway with no attachments has no hourly charge; the run takes a few
# minutes because AWS creates and deletes the gateway asynchronously. The KMS
# key is scheduled for deletion with the module's 30-day window and lingers,
# unusable and free of charge, until then.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "tgw-it"
  }
}

run "smoke" {
  variables {
    name            = run.setup.name
    amazon_side_asn = 64512
    tags            = run.setup.tags
  }

  assert {
    condition     = startswith(output.transit_gateway.id, "tgw-") && startswith(output.transit_gateway.arn, "arn:")
    error_message = "The Transit Gateway must exist and be identified in both output fields."
  }

  assert {
    condition = (
      aws_ec2_transit_gateway.this.default_route_table_association == "disable" &&
      aws_ec2_transit_gateway.this.default_route_table_propagation == "disable" &&
      aws_ec2_transit_gateway.this.auto_accept_shared_attachments == "disable"
    )
    error_message = "The real API must report every TGW default disabled: no default route table association or propagation, no automatic acceptance."
  }

  assert {
    condition = (
      aws_ec2_transit_gateway.this.encryption_support == "enable" &&
      aws_ec2_transit_gateway.this.security_group_referencing_support == "disable" &&
      aws_ec2_transit_gateway.this.multicast_support == "disable" &&
      aws_ec2_transit_gateway.this.dns_support == "enable" &&
      tonumber(aws_ec2_transit_gateway.this.amazon_side_asn) == 64512
    )
    error_message = "Encryption and DNS support are on; security-group referencing and multicast are off; the ASN is the one requested."
  }

  assert {
    condition     = toset(keys(output.route_table_ids)) == toset(["prod", "non-prod", "shared", "inspection", "on-prem"]) && alltrue([for id in values(output.route_table_ids) : startswith(id, "tgw-rtb-")])
    error_message = "Each of the five route domains must have its own real, empty route table."
  }

  assert {
    condition     = aws_ram_resource_share.this.allow_external_principals == false && startswith(output.ram_resource_share_arn, "arn:")
    error_message = "The resource share must exist and refuse principals outside the organization."
  }

  assert {
    condition     = aws_kms_key.flow_logs.enable_key_rotation && output.flow_logs.kms_key_arn == aws_kms_key.flow_logs.arn && aws_cloudwatch_log_group.flow_logs.kms_key_id == aws_kms_key.flow_logs.arn
    error_message = "The flow-log group must be encrypted with the rotating customer-managed key."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.retention_in_days == 365 && output.flow_logs.log_group_name == "/aws/tgw/${run.setup.name}/flow-logs"
    error_message = "The flow-log group must keep records for a year under the documented name."
  }

  assert {
    condition     = startswith(output.flow_logs.id, "fl-") && aws_flow_log.transit_gateway.max_aggregation_interval == 60 && startswith(aws_flow_log.transit_gateway.transit_gateway_id, "tgw-")
    error_message = "AWS must accept the flow log on the Transit Gateway at the one-minute interval."
  }

  assert {
    condition     = strcontains(aws_flow_log.transit_gateway.log_format, "$${tgw-attachment-id}") && strcontains(aws_flow_log.transit_gateway.log_format, "$${packets-lost-blackhole}") && !strcontains(aws_flow_log.transit_gateway.log_format, "$${action}")
    error_message = "The real flow log must carry the Transit Gateway record format."
  }

  assert {
    condition     = strcontains(aws_iam_role.flow_logs.assume_role_policy, "aws:SourceAccount") && strcontains(aws_iam_role.flow_logs.assume_role_policy, "vpc-flow-logs.amazonaws.com")
    error_message = "The flow-log role must be assumable only by the flow-log service, guarded against the confused deputy."
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.rejected_traffic.log_group_name == output.flow_logs.log_group_name && aws_cloudwatch_log_metric_filter.blackholed_traffic.log_group_name == output.flow_logs.log_group_name
    error_message = "Both drop filters must exist on the flow-log group."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.rejected_traffic.arn == output.flow_logs.rejected_traffic_arn && aws_cloudwatch_metric_alarm.rejected_traffic.metric_name == "TransitGatewayRejectedTraffic" && aws_cloudwatch_metric_alarm.rejected_traffic.namespace == "Platform/TransitGateway"
    error_message = "The rejected-traffic alarm must exist and read the metric the filters write."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.arn == output.flow_logs.delivery_stopped_arn && aws_cloudwatch_metric_alarm.flow_log_delivery_stopped.dimensions["LogGroupName"] == output.flow_logs.log_group_name
    error_message = "The delivery-stopped alarm must exist and watch the flow-log group."
  }
}
