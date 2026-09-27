# Transit Gateway Flow Logs are network evidence: every record goes to a log
# group encrypted with a rotating customer-managed key and is retained for at
# least a year. Delivery uses a role that only the flow-log service can assume.
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
  pattern        = local.rejected_no_route_filter_pattern

  metric_transformation {
    name      = "TransitGatewayRejectedTraffic"
    namespace = "Platform/TransitGateway"
    value     = "1"
  }
}

# Explicit blackhole routes drop traffic on purpose; the alarm still wants to
# know when something tries to cross one. Same metric, so one alarm covers both.
resource "aws_cloudwatch_log_metric_filter" "blackholed_traffic" {
  name           = "${var.name}-tgw-blackholed-traffic"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name
  pattern        = local.rejected_blackhole_filter_pattern

  metric_transformation {
    name      = aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].name
    namespace = aws_cloudwatch_log_metric_filter.rejected_traffic.metric_transformation[0].namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "rejected_traffic" {
  alarm_name          = "${var.name}-tgw-rejected-traffic"
  alarm_description   = "Transit Gateway flow logs recorded traffic dropped for lack of a route or by a blackhole route. Investigate route policy, attachment state, and association."
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
