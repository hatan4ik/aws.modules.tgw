# Apply-mode contract test, isolated in its own file because run blocks in one
# file share state and an apply would leak into later plan runs. Under apply
# the mock provider fills computed attributes with random text; the defaults
# below give the identifiers that other resources consume fixed values, so the
# wiring between resources can be compared exactly. The plan-mode files cannot
# do this: those values are unknown until apply.
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

  mock_resource "aws_ec2_transit_gateway" {
    defaults = {
      id  = "tgw-0123456789abcdef0"
      arn = "arn:aws:ec2:us-east-1:123456789012:transit-gateway/tgw-0123456789abcdef0"
    }
  }

  mock_resource "aws_ec2_transit_gateway_route_table" {
    defaults = {
      id = "tgw-rtb-0123456789abcdef0"
    }
  }

  mock_resource "aws_ram_resource_share" {
    defaults = {
      arn = "arn:aws:ram:us-east-1:123456789012:resource-share/11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      key_id = "11111111-2222-3333-4444-555555555555"
      arn    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/tgw/test-regional-tgw/flow-logs"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "test-regional-tgw-tgw-flow-logs"
      arn = "arn:aws:iam::123456789012:role/test-regional-tgw-tgw-flow-logs"
    }
  }

  mock_resource "aws_flow_log" {
    defaults = {
      id = "fl-0123456789abcdef0"
    }
  }

  mock_resource "aws_cloudwatch_metric_alarm" {
    defaults = {
      arn = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:test-regional-tgw-tgw-rejected-traffic"
    }
  }
}

variables {
  name            = "test-regional-tgw"
  amazon_side_asn = 64512
  ram_principals  = ["111122223333", "arn:aws:organizations::111122223333:ou/o-example/ou-ab12-cdef3456"]
}

run "wires_the_hub_the_share_and_the_route_domains_together" {
  command = apply

  assert {
    condition = alltrue([
      for table in values(aws_ec2_transit_gateway_route_table.domain) :
      table.transit_gateway_id == "tgw-0123456789abcdef0"
    ])
    error_message = "Every route-domain table belongs to the hub's TGW."
  }

  assert {
    condition = (
      aws_ram_resource_association.transit_gateway.resource_arn == "arn:aws:ec2:us-east-1:123456789012:transit-gateway/tgw-0123456789abcdef0" &&
      aws_ram_resource_association.transit_gateway.resource_share_arn == aws_ram_resource_share.this.arn
    )
    error_message = "The RAM share carries the hub's TGW and nothing else."
  }

  assert {
    condition = alltrue([
      for association in values(aws_ram_principal_association.approved_principal) :
      association.resource_share_arn == aws_ram_resource_share.this.arn
    ]) && length(aws_ram_principal_association.approved_principal) == 2
    error_message = "Every approved principal is associated with this hub's share."
  }
}

run "wires_flow_log_delivery_encryption_and_alarm_together" {
  command = apply

  assert {
    condition     = aws_kms_alias.flow_logs.target_key_id == aws_kms_key.flow_logs.key_id && aws_cloudwatch_log_group.flow_logs.kms_key_id == aws_kms_key.flow_logs.arn
    error_message = "The log group is encrypted with the hub's flow-log key, and the alias points at it."
  }

  assert {
    condition     = aws_iam_role_policy.flow_logs_delivery.role == aws_iam_role.flow_logs.id
    error_message = "The delivery policy is attached to the flow-log role."
  }

  assert {
    condition = (
      aws_flow_log.transit_gateway.transit_gateway_id == "tgw-0123456789abcdef0" &&
      aws_flow_log.transit_gateway.log_destination == aws_cloudwatch_log_group.flow_logs.arn &&
      aws_flow_log.transit_gateway.iam_role_arn == aws_iam_role.flow_logs.arn &&
      aws_flow_log.transit_gateway.log_destination_type == "cloud-watch-logs"
    )
    error_message = "The flow log watches the hub's TGW and delivers to the encrypted log group through the hub's role."
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.rejected_traffic.log_group_name == aws_cloudwatch_log_group.flow_logs.name && aws_cloudwatch_log_metric_filter.blackholed_traffic.log_group_name == aws_cloudwatch_log_group.flow_logs.name
    error_message = "Both drop filters read the flow-log group."
  }
}

run "reports_the_documented_outputs" {
  command = apply

  assert {
    condition     = output.transit_gateway == { id = "tgw-0123456789abcdef0", arn = "arn:aws:ec2:us-east-1:123456789012:transit-gateway/tgw-0123456789abcdef0" }
    error_message = "transit_gateway carries the TGW ID and ARN for the network-routing, attachment, peering, and VPN compositions."
  }

  assert {
    condition     = output.route_table_ids == { for domain in ["prod", "non-prod", "shared", "inspection", "on-prem"] : domain => "tgw-rtb-0123456789abcdef0" }
    error_message = "route_table_ids maps each domain to its table for the network-routing module."
  }

  assert {
    condition     = output.ram_resource_share_arn == aws_ram_resource_share.this.arn
    error_message = "ram_resource_share_arn reports the share used to audit approved principals."
  }

  assert {
    condition = output.flow_logs == {
      id                   = "fl-0123456789abcdef0"
      log_group_name       = "/aws/tgw/test-regional-tgw/flow-logs"
      kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
      rejected_traffic_arn = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:test-regional-tgw-tgw-rejected-traffic"
    }
    error_message = "flow_logs reports the flow log, the encrypted log group, its key, and the rejected-traffic alarm."
  }
}
