data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_ec2_transit_gateway" "this" {
  description                     = "Segmented regional transit gateway ${var.name}"
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  encryption_support              = "enable"

  # Cross-VPC security-group references would bypass the explicit, account-owned
  # security-group policy. Keep this disabled unless a future ADR changes it.
  security_group_referencing_support = "disable"
  vpn_ecmp_support                   = "enable"

  tags = local.common_tags
}

resource "aws_ec2_transit_gateway_route_table" "domain" {
  for_each = local.route_domains

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-${each.key}"
    RouteDomain = each.key
  })
}

resource "aws_ram_resource_share" "this" {
  name                      = "${var.name}-attachment-share"
  allow_external_principals = false

  tags = local.common_tags
}

resource "aws_ram_resource_association" "transit_gateway" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.this.arn
}

resource "aws_ram_principal_association" "approved_principal" {
  for_each = local.ram_principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this.arn
}

resource "aws_kms_key" "flow_logs" {
  description             = "Encrypts Transit Gateway Flow Logs for ${var.name}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.flow_logs_kms_policy

  tags = merge(local.common_tags, {
    Name      = "${var.name}-tgw-flow-logs"
    DataClass = "network-observability"
  })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.name}-tgw-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = local.flow_log_group_name
  retention_in_days = var.flow_log_retention_in_days
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-tgw-flow-logs"
  assume_role_policy = local.flow_logs_assume_role_policy

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs_delivery" {
  name   = "${var.name}-tgw-flow-logs-delivery"
  role   = aws_iam_role.flow_logs.id
  policy = local.flow_logs_delivery_policy
}

# TGW flow logs are ownership-plane evidence. AWS requires the one-minute
# aggregation interval and rejects traffic_type for TransitGateway resources.
resource "aws_flow_log" "transit_gateway" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  log_format               = local.flow_log_format
  max_aggregation_interval = 60
  transit_gateway_id       = aws_ec2_transit_gateway.this.id

  depends_on = [aws_iam_role_policy.flow_logs_delivery]

  tags = merge(local.common_tags, {
    Name = "${var.name}-tgw-all-traffic"
  })
}

resource "aws_cloudwatch_log_metric_filter" "rejected_traffic" {
  name           = "${var.name}-tgw-rejected-traffic"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name
  pattern        = local.rejected_traffic_filter_pattern

  metric_transformation {
    name      = "TransitGatewayRejectedTraffic"
    namespace = "Platform/TransitGateway"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "rejected_traffic" {
  alarm_name          = "${var.name}-tgw-rejected-traffic"
  alarm_description   = "Transit Gateway flow logs recorded rejected traffic. Investigate route policy, attachment state, and security controls."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = var.rejected_traffic_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = tolist(var.rejected_traffic_alarm_actions)

  tags = local.common_tags
}
