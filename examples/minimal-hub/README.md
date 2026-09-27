# Minimal hub

The smallest useful call: a name and an Amazon-side ASN. It creates one regional
Transit Gateway with every default disabled (no default route table
association or propagation, no automatic attachment acceptance), one empty
route table for each of the five ADR 0003 route domains (`prod`, `non-prod`,
`shared`, `inspection`, `on-prem`), an encrypted Transit Gateway Flow Log kept for
365 days, a rejected-traffic alarm, and a RAM share that is not yet shared with
anyone.

Nothing can reach anything through this hub yet. Attachments arrive later:
spokes request them ([`../spoke-attachment`](../spoke-attachment)) and the
network account accepts, classifies, and routes them
([`../segmented-domains`](../segmented-domains)). The hub owner's own VPCs need no
RAM share; share with other accounts through `ram_principals` (see
[`../organization-share`](../organization-share)).

The alarm has no action until you pass `rejected_traffic_alarm_actions`, so
until then it is visible in the console only.

## Run

```sh
terraform init
terraform plan -var name=platform-use2 -var amazon_side_asn=64512
```

Run it with credentials for the Network account. A Transit Gateway has no
hourly charge of its own; attachments and the data they process do.

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
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Private BGP ASN for the Amazon side of the hub, from the enterprise allocation: 64512-65534 or 4200000000-4294967294. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Hub name, 3-50 lowercase letters, digits, and hyphens. It prefixes every resource, including the flow-log role. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the hub. A Transit Gateway is regional; add one hub per Region. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation and ownership tags applied to every resource the hub creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_logs"></a> [flow\_logs](#output\_flow\_logs) | Flow log, encrypted log group, key, and rejected-traffic alarm identifiers. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Route-domain to route-table ID map that the network account passes to modules/network-routing. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Hub TGW ID and ARN, the identifiers the network-routing module, workload attachments, and separately approved VPN or peering compositions consume. |
<!-- END_TF_DOCS -->
