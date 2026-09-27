# network-routing

The network account's half of the attachment handshake. It takes the cross-account VPC attachments a spoke has requested and, for each one the network account has approved, accepts it, verifies who owns the VPC, assigns its route domain, associates it with exactly one route table, propagates it only where the matrix allows, and installs the static and blackhole routes the network account declares. It is the segmentation trust boundary of ADR 0003 (see [docs/DESIGN.md](../../docs/DESIGN.md)) and belongs only in the account that owns the Transit Gateway.

A workload account never supplies a route domain: its attachment key is a lookup key, and the network-side `approved_account_domains` map is the only classification. Attachment tags are evidence, never input.

## Usage

```hcl
module "routing" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/network-routing?ref=<commit-sha>" # v1.0.0

  route_table_ids = module.hub.route_table_ids

  approved_account_domains = {
    "111122223333" = "prod"
    "444455556666" = "non-prod"
  }

  attachments = {
    prod-app    = { attachment_id = "tgw-attach-0123456789abcdef0", account_id = "111122223333" }
    nonprod-app = { attachment_id = "tgw-attach-0fedcba9876543210", account_id = "444455556666" }
  }

  # Deny by absence: a destination that is not listed receives no route.
  propagation_matrix = {
    prod       = ["prod", "shared"]
    non-prod   = ["non-prod", "shared"]
    shared     = ["prod", "non-prod", "shared"]
    inspection = ["inspection"]
    on-prem    = ["prod", "non-prod", "shared", "on-prem"]
  }

  static_routes = {
    non-prod-private-supernet = {
      route_table_domain     = "non-prod"
      destination_cidr_block = "10.0.0.0/8"
      blackhole              = true
    }
  }
}
```

See [`examples/segmented-domains`](../../examples/segmented-domains) for the hub and this module in one root.

## What it enforces

| Rule | Enforced by |
| --- | --- |
| Every domain has its own route table. | Validation on `route_table_ids` (distinct IDs). |
| An attachment is accepted only from an account the network account approved, and that account has a domain. | Precondition on `terraform_data.network_policy`. |
| The VPC owner AWS reports equals the approved account, before anything is associated or propagated. | Postcondition on `aws_ec2_transit_gateway_vpc_attachment_accepter.approved`; association, propagation, and routes depend on the accepter's ID. |
| Every domain the policy names exists, and every domain with an attachment has a matrix entry, even an empty one. | Preconditions on `terraform_data.network_policy`. |
| `prod` never propagates into `non-prod` or the reverse, and a static route in one of those tables never targets an attachment of the other (ADR 0003). | Preconditions on `terraform_data.network_policy`. Blackholes are always allowed. |
| A static route is a canonical CIDR and exactly one of a blackhole or an approved attachment, once per table and prefix. | Validation on `static_routes`, and a precondition for the target. |
| Nothing joins a default route table. | `transit_gateway_default_route_table_association` and `..._propagation` are false on the accepter. |

Every resource depends on `terraform_data.network_policy`, so a failed rule creates nothing.

The module accepts an attachment before it can compare the owner AWS reports with the approved account; there is no earlier API. If they differ the apply fails and nothing is associated or propagated, but the accepted attachment stays unrouted until you remove it from `attachments` and reject it.

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_route.static](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route) | resource |
| [aws_ec2_transit_gateway_route_table_association.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment_accepter.approved](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment_accepter) | resource |
| [terraform_data.network_policy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_approved_account_domains"></a> [approved\_account\_domains](#input\_approved\_account\_domains) | Network-owned map of workload AWS account ID to its only permitted TGW route domain. Spoke code cannot select a domain. | `map(string)` | n/a | yes |
| <a name="input_attachments"></a> [attachments](#input\_attachments) | Network-approved cross-account VPC attachment IDs and their expected VPC-owner account IDs, keyed by the catalog key the spoke was given. Route domains are intentionally absent. | <pre>map(object({<br/>    attachment_id = string<br/>    account_id    = string<br/>  }))</pre> | n/a | yes |
| <a name="input_propagation_matrix"></a> [propagation\_matrix](#input\_propagation\_matrix) | Network-owned source-domain to destination-route-domain propagation policy. Omitted destinations receive no propagated route. Every domain that has an attachment needs an entry, even an empty one. | `map(set(string))` | n/a | yes |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Network-account-owned map of route domain to TGW route-table ID, normally output by the TGW hub module. Every domain has its own route table. | `map(string)` | n/a | yes |
| <a name="input_static_routes"></a> [static\_routes](#input\_static\_routes) | Explicit network-account routes. A route is either a blackhole or targets an approved attachment key; it never falls back to a default route. | <pre>map(object({<br/>    route_table_domain     = string<br/>    destination_cidr_block = string<br/>    blackhole              = bool<br/>    target_attachment_key  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional ownership and allocation tags applied to network-account routing resources. Component and RouteDomain are computed by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_accepted_attachments"></a> [accepted\_attachments](#output\_accepted\_attachments) | Accepted cross-account attachment IDs and verified VPC-owner account IDs. |
| <a name="output_attachment_domains"></a> [attachment\_domains](#output\_attachment\_domains) | Network-account-assigned route domain by approved attachment key. |
| <a name="output_propagation_ids"></a> [propagation\_ids](#output\_propagation\_ids) | Explicit attachment-to-route-table propagation resource IDs keyed by attachment and destination domain. |
<!-- END_TF_DOCS -->
