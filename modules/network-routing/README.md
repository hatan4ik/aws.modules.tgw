# terraform-aws-tgw-hub/modules/network-routing

Network-account-only composition for cross-account VPC attachments. The
Network account supplies the account-to-domain catalog, accepts each attachment,
verifies the VPC-owner account, associates the attachment with exactly one TGW
route table, applies the explicit propagation matrix, and creates optional
static or blackhole routes.

A workload account never supplies a route domain. Its attachment key is only a
lookup key; the network-side `approved_account_domains` map is the trust
boundary. Omitted matrix entries result in no propagation.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ec2_transit_gateway_route.static](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route) | resource |
| [aws_ec2_transit_gateway_route_table_association.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment_accepter.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment_accepter) | resource |
| [terraform_data.network_policy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_approved_account_domains"></a> [approved\_account\_domains](#input\_approved\_account\_domains) | Network-owned map of workload AWS account ID to its only permitted TGW route domain. Spoke code cannot select a domain. | `map(string)` | n/a | yes |
| <a name="input_attachments"></a> [attachments](#input\_attachments) | Network-approved cross-account VPC attachment IDs and their expected VPC-owner account IDs. Route domains are intentionally absent. | <pre>map(object({<br/>    attachment_id = string<br/>    account_id    = string<br/>  }))</pre> | n/a | yes |
| <a name="input_propagation_matrix"></a> [propagation\_matrix](#input\_propagation\_matrix) | Network-owned source-domain to destination-route-domain propagation policy. Omitted destinations receive no propagated route. | `map(set(string))` | n/a | yes |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Network-account-owned map of route domain to TGW route-table ID, normally output by the TGW hub module. | `map(string)` | n/a | yes |
| <a name="input_static_routes"></a> [static\_routes](#input\_static\_routes) | Explicit network-account routes. A route is either a blackhole or targets an approved attachment key; it never falls back to a default route. | <pre>map(object({<br/>    route_table_domain     = string<br/>    destination_cidr_block = string<br/>    blackhole              = bool<br/>    target_attachment_key  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional ownership and allocation tags applied to network-account routing resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_accepted_attachments"></a> [accepted\_attachments](#output\_accepted\_attachments) | Accepted cross-account attachment IDs and verified VPC-owner account IDs. |
| <a name="output_attachment_domains"></a> [attachment\_domains](#output\_attachment\_domains) | Network-account-assigned route domain by approved attachment key. |
| <a name="output_propagation_ids"></a> [propagation\_ids](#output\_propagation\_ids) | Explicit attachment-to-route-table propagation resource IDs keyed by attachment and destination domain. |
<!-- END_TF_DOCS -->
