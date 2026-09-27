# Organization share

Shares the hub through AWS RAM with an AWS Organization, or with selected
organizational units, so accounts do not have to be listed one by one.

Two things must be true before the apply succeeds, and neither is managed here:

- **RAM sharing with AWS Organizations is enabled** by the management account
  (`aws ram enable-sharing-with-aws-organization`, or the RAM console's
  Settings). Without it AWS refuses an organization or OU principal.
- **The Network account is a member of the organization.** The share sets
  `allow_external_principals = false`, so it can never reach an account outside
  it, whatever `ram_principals` says.

Sharing only makes the Transit Gateway visible. It does not let anyone route
through it. The hub accepts nothing automatically and associates nothing with a
default route table, so every attachment a spoke requests waits for the network
account's routing composition ([`../segmented-domains`](../segmented-domains))
to accept, classify, and route it.

To share with specific OUs instead of the whole organization, set
`workload_ou_arns`; `organization_arn` is then not shared. Individual accounts
can be shared the same way with 12-digit IDs (see
[`../segmented-domains`](../segmented-domains)). Audit the result with the
`ram_resource_share_arn` output: list its principal associations to see exactly
who may request attachments.

```sh
terraform init
terraform plan \
  -var name=platform-use2 \
  -var amazon_side_asn=64512 \
  -var organization_arn=arn:aws:organizations::999999999999:organization/o-a1b2c3d4e5
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
| <a name="module_hub"></a> [hub](#module\_hub) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | SNS topic or incident-management ARNs notified when the hub drops traffic for lack of a route or at a blackhole. At most five. | `set(string)` | `[]` | no |
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Private BGP ASN for the Amazon side of the hub, from the enterprise allocation. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Hub name, 3-50 lowercase letters, digits, and hyphens. | `string` | n/a | yes |
| <a name="input_organization_arn"></a> [organization\_arn](#input\_organization\_arn) | ARN of the AWS Organization to share with, in the form arn:aws:organizations::<management-account-id>:organization/o-xxxxxxxxxx. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the hub. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation and ownership tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_workload_ou_arns"></a> [workload\_ou\_arns](#input\_workload\_ou\_arns) | Organizational unit ARNs to share with instead of the whole organization, in the form arn:aws:organizations::<management-account-id>:ou/o-xxxxxxxxxx/ou-xxxx-xxxxxxxx. Empty shares with the organization. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | RAM share ARN. Audit its principal associations to see exactly who may request attachments. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Hub TGW ID and ARN. Spokes in the shared organization or OUs use the ID to request attachments. |
<!-- END_TF_DOCS -->
