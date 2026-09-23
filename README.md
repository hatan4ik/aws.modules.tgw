# terraform-aws-tgw-hub

Creates one regional Transit Gateway, configurable deny-by-default route domains,
an encrypted Transit Gateway Flow Log, rejected-traffic alarm, and a RAM share
for approved AWS accounts or AWS Organizations principals. Default route-table
association, propagation, and automatic attachment acceptance are disabled.

Cross-account VPC acceptance, network-account domain assignment, explicit
associations, propagation, and static/blackhole routes are implemented by the
[`modules/network-routing`](modules/network-routing/) submodule. Spokes use
[`modules/vpc-attachment`](modules/vpc-attachment/) only to request an
unclassified attachment; they cannot select a route domain. VPN, peering, and
on-premises routing remain separate approved compositions. See ADR 0003 and
ADR 0005.

The Phase 6 module-release workflow checks that the generated `terraform-docs` section below is current.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.rejected_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.rejected_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_flow_log.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_ram_principal_association.approved_principal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Approved private BGP ASN for the Amazon side of this regional Transit Gateway. | `number` | n/a | yes |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | CloudWatch Logs retention for Transit Gateway Flow Logs. Network evidence is retained for at least one year. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Lowercase Transit Gateway hub name used in resource names and tags. | `string` | n/a | yes |
| <a name="input_ram_principal_arns"></a> [ram\_principal\_arns](#input\_ram\_principal\_arns) | Deprecated compatibility input. Use ram\_principals, which also accepts 12-digit AWS account IDs. | `set(string)` | `[]` | no |
| <a name="input_ram_principals"></a> [ram\_principals](#input\_ram\_principals) | AWS account IDs or AWS Organizations organization/OU ARNs permitted to create VPC attachments to this TGW. | `set(string)` | `null` | no |
| <a name="input_rejected_traffic_alarm_actions"></a> [rejected\_traffic\_alarm\_actions](#input\_rejected\_traffic\_alarm\_actions) | Optional SNS or incident-management action ARNs notified by the rejected-TGW-traffic alarm. | `set(string)` | `[]` | no |
| <a name="input_rejected_traffic_alarm_threshold"></a> [rejected\_traffic\_alarm\_threshold](#input\_rejected\_traffic\_alarm\_threshold) | Rejected TGW flow-log records that trigger the five-minute rejected-traffic alarm. | `number` | `1` | no |
| <a name="input_route_domains"></a> [route\_domains](#input\_route\_domains) | Network-owned TGW route domains. Attachments are associated later by the separate network-routing module. | `set(string)` | <pre>[<br/>  "prod",<br/>  "non-prod",<br/>  "shared",<br/>  "inspection",<br/>  "on-prem"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and Component tags are computed by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_flow_logs"></a> [flow\_logs](#output\_flow\_logs) | Transit Gateway Flow Log, encrypted log group, KMS key, and rejected-traffic alarm identifiers. |
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | RAM resource share ARN used to audit approved TGW attachment principals. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Network-owned route-domain to TGW route-table ID mapping consumed by the separate network-routing module. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Regional TGW identifiers needed by separately approved network routing, workload attachment, peering, and VPN composition. |
<!-- END_TF_DOCS -->
