# Internal TGW VPC attachment module

Creates the workload-account side of a non-default Transit Gateway VPC
attachment. It accepts dedicated transit subnet IDs and an opaque
`attachment_key`; the Network account assigns the route domain and performs
acceptance, association, and propagation through `modules/network-routing`.
Appliance mode is disabled by default and must be explicitly enabled only for
an approved inspection appliance attachment.

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
| <a name="input_appliance_mode_support"></a> [appliance\_mode\_support](#input\_appliance\_mode\_support) | Enable only for a reviewed inspection appliance attachment that requires AZ-affine return traffic. Workload attachments keep it disabled. | `bool` | `false` | no |
| <a name="input_attachment_key"></a> [attachment\_key](#input\_attachment\_key) | Network-catalog key used by the TGW owner to locate and classify this attachment. It is not a route domain. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase attachment name used in tags. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | One private subnet per selected AZ for the TGW attachment. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and RouteDomain are computed by the module. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | ID of the approved regional Transit Gateway shared with this workload account. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the private workload VPC receiving the attachment. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_attachment"></a> [attachment](#output\_attachment) | Attachment ID and network-catalog key for the Network account's separate acceptance/association root. |
<!-- END_TF_DOCS -->
