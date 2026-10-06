# spoke-routes

Phase 3 of the cross-account Transit Gateway handshake. It creates spoke VPC routes only after consuming the exact machine-readable receipt emitted by the Network account's `modules/network-routing` apply.

This module removes the timing race between a spoke attachment in `pendingAcceptance` and VPC route creation. It does not poll AWS or bypass account ownership: the Network account remains the only party that can verify, classify, associate, and propagate an attachment.

## GitOps usage

Phase 1, in the workload account, requests the attachment:

```hcl
module "attachment" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/vpc-attachment?ref=<commit-sha>" # release tag

  name               = "prod-app-use2"
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  attachment_key     = "prod-app-use2"
}
```

Phase 2 is a separate Network-account pipeline. It adds the attachment to `modules/network-routing` and publishes `route_activation_receipts` in that root's remote state.

Phase 3, back in the workload account, consumes only its catalog receipt:

```hcl
data "terraform_remote_state" "network_routing" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_routing_state_key
    region = var.network_state_region
  }
}

module "spoke_routes" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/spoke-routes?ref=<commit-sha>" # release tag

  attachment = module.attachment.attachment
  network_acceptance_receipt = data.terraform_remote_state.network_routing.outputs.route_activation_receipts[
    module.attachment.attachment.attachment_key
  ]

  routes = {
    private-a = { route_table_id = module.vpc.private_route_table_ids[0], destination_cidr_block = "10.0.0.0/8" }
    private-b = { route_table_id = module.vpc.private_route_table_ids[1], destination_cidr_block = "10.0.0.0/8" }
  }
}
```

Use a read-only backend role or narrowly scoped state-output publication for the workload pipeline. Terraform state can contain sensitive data; this module does not grant access to the Network account's backend.

The apply fails before any `aws_route` is created unless the receipt:

- is contract version 1 and marked ready;
- names the exact Phase 1 attachment key and ID;
- proves AWS reported the current workload account as the VPC owner; and
- contains the completed Network-account route-table association.

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
| [aws_route.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [terraform_data.route_activation_barrier](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attachment"></a> [attachment](#input\_attachment) | Phase 1 spoke attachment contract, normally module.vpc\_attachment.attachment. The key and ID must match the Network account's Phase 2 receipt. | <pre>object({<br/>    id             = string<br/>    attachment_key = string<br/>  })</pre> | n/a | yes |
| <a name="input_network_acceptance_receipt"></a> [network\_acceptance\_receipt](#input\_network\_acceptance\_receipt) | Phase 2 receipt from modules/network-routing.route\_activation\_receipts[attachment\_key]. Routes remain blocked unless it proves the same attachment was owner-verified, associated, and propagated by the Network account. | <pre>object({<br/>    contract_version          = number<br/>    ready                     = bool<br/>    attachment_key            = string<br/>    attachment_id             = string<br/>    transit_gateway_id        = string<br/>    vpc_owner_id              = string<br/>    route_domain              = string<br/>    associated_route_table_id = string<br/>    association_id            = string<br/>    propagation_ids           = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_routes"></a> [routes](#input\_routes) | Phase 3 VPC routes, keyed by a stable catalog name. Each route is installed only after the acceptance receipt passes every barrier. | <pre>map(object({<br/>    route_table_id         = string<br/>    destination_cidr_block = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_routes"></a> [routes](#output\_routes) | Activated VPC routes and the verified network receipt identity that authorized them. |
<!-- END_TF_DOCS -->
