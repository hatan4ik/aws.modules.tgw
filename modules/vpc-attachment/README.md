# Internal TGW VPC attachment module

Creates a private workload VPC attachment with default Transit Gateway route association and propagation disabled. A Network-account root must separately accept and associate it with the approved route domain. This module deliberately does not configure routes or cross-account provider credentials.

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
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Lowercase attachment name used in tags. | `string` | n/a | yes |
| <a name="input_route_domain"></a> [route\_domain](#input\_route\_domain) | ADR-defined TGW route domain selected for this attachment. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | One private subnet per selected AZ for the TGW attachment. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and RouteDomain are computed by the module. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | ID of the approved regional Transit Gateway shared with this workload account. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the private workload VPC receiving the attachment. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_attachment"></a> [attachment](#output\_attachment) | Attachment ID and selected route domain for the Network account's separate acceptance/association root. |
<!-- END_TF_DOCS -->
