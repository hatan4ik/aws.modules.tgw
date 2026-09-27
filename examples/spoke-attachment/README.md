# Spoke attachment

What a workload account does: request an attachment for its VPC to the shared
Transit Gateway. It is created in `pendingAcceptance` and is attached to no route
table. The module has no route-domain input and rejects a `RouteDomain` tag, so
a spoke cannot classify its own attachment. Only the Network account can accept,
classify, and route it (see [`../segmented-domains`](../segmented-domains)).

## Handshake

1. The network team gives you an `attachment_key` and shares the hub with your
   account through RAM. Inside an AWS Organization the share is accepted
   automatically and the Transit Gateway ID is visible in your account.
2. Apply this example. Report `attachment.id` and your account ID to the network
   team.
3. The network team accepts the attachment, assigns your route domain, and
   applies its routing. Nothing flows before that.
4. Only after acceptance, add routes to the hub in your VPC route tables (for
   example with `transit_gateway_id` in [`aws.modules.vpc`](https://github.com/hatan4ik/aws.modules.vpc)).
   A route to a Transit Gateway cannot be created while the attachment is
   pending, so do this in a second change.

Enable `appliance_mode_support` only for a reviewed inspection appliance
attachment.

```sh
terraform init
terraform plan \
  -var name=prod-app-use2 \
  -var attachment_key=prod-app-use2 \
  -var transit_gateway_id=tgw-0123456789abcdef0 \
  -var vpc_id=vpc-0123456789abcdef0 \
  -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_attachment"></a> [attachment](#module\_attachment) | ../../modules/vpc-attachment | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attachment_key"></a> [attachment\_key](#input\_attachment\_key) | Catalog key issued by the network team, 3-63 lowercase letters, digits, and hyphens. It identifies this attachment to them and is not a route domain. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Attachment name, 3-63 lowercase letters, digits, and hyphens. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the Transit Gateway and of the VPC. They must match. | `string` | `"us-east-2"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | One private subnet per Availability Zone to attach, at least two. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation and ownership tags. RouteDomain is reserved for the network account and rejected. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | ID of the Transit Gateway that the Network account shared with this account through AWS RAM. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of this account's VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_attachment"></a> [attachment](#output\_attachment) | Attachment ID and catalog key to report to the network team, which adds them to its attachment catalog. |
<!-- END_TF_DOCS -->
