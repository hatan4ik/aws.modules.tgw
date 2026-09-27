# Segmented domains

The Network account's whole job in one root: the hub, and the routing
composition that turns requested attachments into segmented connectivity.

1. `module.hub` creates the Transit Gateway, the five route domains, the RAM
   share for the approved accounts, and the flow log and alarm.
2. A spoke requests an attachment ([`../spoke-attachment`](../spoke-attachment))
   and reports its ID.
3. You add the attachment to the `attachments` variable, the spoke's account
   to `approved_account_domains`, and apply. `module.routing` then accepts the
   attachment, checks that the VPC owner is the approved account (a mismatch
   fails the apply before anything is associated or propagated), associates
   the attachment with its domain's route table, propagates it into the
   destinations the matrix lists, and installs the blackhole route.

The propagation matrix is a local in [`main.tf`](main.tf) so the policy is
reviewed as code. In it `prod` and `non-prod` never receive each other's routes.
Adding one to the other's list fails the plan (ADR 0003), and so does a static
route in one table that targets an attachment of the other.

## Inputs to prepare

```hcl
name                     = "platform-use2"
amazon_side_asn          = 64512
private_supernet         = "10.0.0.0/8"
alarm_actions            = ["arn:aws:sns:us-east-2:999999999999:network-sre"]

approved_account_domains = {
  "111122223333" = "prod"
  "444455556666" = "non-prod"
  "777788889999" = "shared"
}

# Empty on the first apply. Add entries as spokes report their attachment IDs.
attachments = {
  prod-app = {
    attachment_id = "tgw-attach-0123456789abcdef0"
    account_id    = "111122223333"
  }
}
```

```sh
terraform init
terraform plan
```

The first apply creates the hub with an empty catalog; every later apply adds
the attachments that were approved. The accounts in `approved_account_domains`
must belong to your AWS Organization, because the RAM share never allows
principals outside it.

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
| <a name="module_routing"></a> [routing](#module\_routing) | ../../modules/network-routing | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | SNS topic or incident-management ARNs notified when the hub drops traffic for lack of a route or at a blackhole. At most five. | `set(string)` | `[]` | no |
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Private BGP ASN for the Amazon side of the hub, from the enterprise allocation. | `number` | n/a | yes |
| <a name="input_approved_account_domains"></a> [approved\_account\_domains](#input\_approved\_account\_domains) | Workload account ID to its one route domain, for example { "111122223333" = "prod" }. These accounts are also the RAM principals that may request attachments. Only the network account edits this map. | `map(string)` | n/a | yes |
| <a name="input_attachments"></a> [attachments](#input\_attachments) | Attachments the network account has decided to accept, keyed by the catalog key the spoke was given. Each names the attachment ID the spoke reported and the account expected to own the VPC. Empty until the first spoke has requested an attachment. | <pre>map(object({<br/>    attachment_id = string<br/>    account_id    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Hub name, 3-50 lowercase letters, digits, and hyphens. | `string` | n/a | yes |
| <a name="input_private_supernet"></a> [private\_supernet](#input\_private\_supernet) | Private address supernet, for example an IPAM top-level pool CIDR, that is blackholed in the non-prod route table so non-production reaches only the routes propagated to it. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the hub. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation and ownership tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_accepted_attachments"></a> [accepted\_attachments](#output\_accepted\_attachments) | Accepted attachment IDs with the verified VPC-owner account and assigned domain. |
| <a name="output_attachment_domains"></a> [attachment\_domains](#output\_attachment\_domains) | Route domain the network account assigned to each attachment key. |
| <a name="output_propagation_ids"></a> [propagation\_ids](#output\_propagation\_ids) | Propagation resource IDs keyed by attachment and destination domain. |
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | RAM share through which the approved accounts see the hub. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Hub TGW ID and ARN to hand to the spokes that request attachments. |
<!-- END_TF_DOCS -->
