# vpc-attachment

The spoke's half of the attachment handshake. A workload account uses it to **request** a VPC attachment to the regional Transit Gateway that the network account shared with it. The attachment is created in `pendingAcceptance` and joins no route table: default route-table association and propagation are off, and there is deliberately no input for a route domain. The Transit Gateway owner accepts, classifies, associates, and propagates it with [`modules/network-routing`](../network-routing) (ADR 0003, see [docs/DESIGN.md](../../docs/DESIGN.md)).

A spoke also cannot label its own attachment: a `RouteDomain` tag is rejected, in any letter case, and `Name`, `AttachmentKey`, and `Component` are computed and override caller tags. The `attachment_key` is a catalog key the network team issues; it is not a route domain and selects nothing.

## Usage

```hcl
module "attachment" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/vpc-attachment?ref=<commit-sha>" # v1.0.0

  name               = "prod-app-use2"
  transit_gateway_id = "tgw-0123456789abcdef0" # shared by the network account through RAM
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids # at least two, one per Availability Zone
  attachment_key     = "prod-app-use2"            # issued by the network team

  tags = { Owner = "workload-team" }
}

output "attachment" {
  value = module.attachment.attachment # report id and attachment_key to the network team
}
```

See [`examples/spoke-attachment`](../../examples/spoke-attachment) for a complete root.

Enable `appliance_mode_support` only for a reviewed inspection appliance attachment. Add routes to the Transit Gateway in your VPC route tables only after the network account has accepted and routed the attachment.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_appliance_mode_support"></a> [appliance\_mode\_support](#input\_appliance\_mode\_support) | Enable only for a reviewed inspection appliance attachment that requires AZ-affine return traffic. Workload attachments keep it disabled. | `bool` | `false` | no |
| <a name="input_attachment_key"></a> [attachment\_key](#input\_attachment\_key) | Network-catalog key used by the TGW owner to locate this attachment. It is not a route domain. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase attachment name used in tags. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | One private subnet per selected AZ for the TGW attachment. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name, AttachmentKey, and Component are computed by the module. RouteDomain is reserved for the network account and rejected here. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | ID of the approved regional Transit Gateway shared with this workload account. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the private workload VPC receiving the attachment. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_attachment"></a> [attachment](#output\_attachment) | Attachment ID and network-catalog key for the Network account's separate acceptance/association root. |
<!-- END_TF_DOCS -->
