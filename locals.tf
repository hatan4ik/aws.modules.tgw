locals {
  route_domains  = toset(var.route_domains)
  ram_principals = var.ram_principals == null ? var.ram_principal_arns : var.ram_principals

  # ADR 0003: an attachment associates with exactly one of these route domains.
  adr_route_domains = toset(["prod", "non-prod", "shared", "inspection", "on-prem"])

  common_tags = merge(var.tags, {
    Name      = var.name
    Component = "transit-gateway-hub"
  })

  flow_log_group_name = "/aws/tgw/${var.name}/flow-logs"
  flow_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.flow_log_group_name}"

  flow_logs_kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRootAdministration"
        Effect    = "Allow"
        Action    = "kms:*"
        Resource  = "*"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      },
      {
        Sid    = "AllowCloudWatchLogsForThisLogGroup"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource  = "*"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = local.flow_log_group_arn
          }
        }
      },
    ]
  })

  # AWS recommends aws:SourceAccount and aws:SourceArn on flow-log roles to
  # prevent a confused deputy. The flow log's own ID does not exist before the
  # role does, so the ARN is scoped to this account and Region.
  flow_logs_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
        }
      }
    }]
  })

  flow_logs_delivery_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${local.flow_log_group_arn}:*"
    }]
  })

  # Transit Gateway flow-log record fields, in record order. Only fields from
  # the AWS Transit Gateway flow-log reference are valid here: the VPC flow-log
  # names (transit-gateway-id, action, ...) are rejected by CreateFlowLogs. The
  # ordered custom format lets the metric filters find the drop counters
  # without relying on AWS's default record layout. The two drop counters must
  # stay the last two fields; the filter patterns below name them.
  flow_log_fields = [
    "version",
    "resource-type",
    "account-id",
    "tgw-id",
    "tgw-attachment-id",
    "tgw-src-vpc-account-id",
    "tgw-dst-vpc-account-id",
    "tgw-src-vpc-id",
    "tgw-dst-vpc-id",
    "srcaddr",
    "dstaddr",
    "srcport",
    "dstport",
    "protocol",
    "packets",
    "bytes",
    "start",
    "end",
    "log-status",
    "flow-direction",
    "packets-lost-mtu-exceeded",
    "packets-lost-ttl-expired",
    "packets-lost-no-route",
    "packets-lost-blackhole",
  ]

  flow_log_format = join(" ", [for field in local.flow_log_fields : "$${${field}}"])

  # A Transit Gateway record has no accept/reject action. Traffic the hub
  # refuses is counted in packets-lost-no-route (no route in the source
  # attachment's table: the deny-by-default case) and packets-lost-blackhole
  # (an explicit blackhole route). A space-delimited pattern is documented to
  # combine || only within one field, so each counter has its own filter and
  # both feed the same metric.
  rejected_no_route_filter_pattern  = "[..., packets_lost_no_route > 0, packets_lost_blackhole]"
  rejected_blackhole_filter_pattern = "[..., packets_lost_no_route, packets_lost_blackhole > 0]"
}
