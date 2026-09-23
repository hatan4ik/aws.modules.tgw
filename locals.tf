locals {
  route_domains  = toset(var.route_domains)
  ram_principals = var.ram_principals == null ? var.ram_principal_arns : var.ram_principals

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

  flow_logs_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
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

  # The ordered format lets the metric filter identify rejected records without
  # relying on AWS's mutable default flow-log record layout.
  flow_log_format = join(" ", [
    "$${version}",
    "$${account-id}",
    "$${transit-gateway-id}",
    "$${transit-gateway-attachment-id}",
    "$${srcaddr}",
    "$${dstaddr}",
    "$${srcport}",
    "$${dstport}",
    "$${protocol}",
    "$${packets}",
    "$${bytes}",
    "$${start}",
    "$${end}",
    "$${action}",
    "$${log-status}",
  ])

  rejected_traffic_filter_pattern = "[version, account_id, transit_gateway_id, transit_gateway_attachment_id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action = REJECT, log_status]"
}
