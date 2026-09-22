# terraform-aws-tgw-hub

Creates one regional Transit Gateway, a fixed deny-by-default set of route domains (`prod`, `non-prod`, `shared`, `inspection`, and `on-prem`), and an organization-only RAM share for approved principals. Default route-table association, propagation, and automatic attachment acceptance are disabled.

VPC/VPN/peering attachments and routes are intentionally outside this module: they are account-specific composition with separate approval and failure domains. See ADR 0003 and ADR 0005.

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
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ram_principal_association.approved_principal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Approved private BGP ASN for the Amazon side of this regional Transit Gateway. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase Transit Gateway hub name used in resource names and tags. | `string` | n/a | yes |
| <a name="input_ram_principal_arns"></a> [ram\_principal\_arns](#input\_ram\_principal\_arns) | AWS Organizations or account principals allowed to attach approved VPCs to this TGW through RAM. | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and Component tags are computed by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | RAM resource share ARN used to audit approved attachment principals. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Fixed route-domain to TGW route-table ID mapping for explicit attachment association. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Regional TGW identifiers needed by workload attachment and peering composition. |
<!-- END_TF_DOCS -->
