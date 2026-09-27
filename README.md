# aws.modules.tgw

The regional Transit Gateway hub of the platform network. One module call creates one hub: a Transit Gateway with every default disabled, one deny-by-default route table per route domain, an encrypted Transit Gateway Flow Log with an alarm on dropped traffic, and an AWS RAM share for the accounts or Organization principals that may request attachments. Two submodules cover the other parties in the attachment handshake: `modules/network-routing` lets the network account accept, verify, classify, associate, propagate, and route each cross-account attachment, and `modules/vpc-attachment` lets a spoke request an **unclassified** attachment and nothing more. It implements ADR 0003 (segmented Transit Gateway hubs) as code, is secure by default and explicit by declaration, and manages no VPN, peering, or on-premises routing. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get from a name and an ASN, without setting anything else:

- Deny by default. Default route-table association, default propagation, and automatic acceptance of shared attachments are off, and one empty route table exists per route domain (`prod`, `non-prod`, `shared`, `inspection`, `on-prem`). An attachment reaches nothing until the network account associates and propagates it.
- Three roles that cannot cross. The hub owner creates the gateway; the network account alone accepts, classifies, and routes attachments; a spoke can only request one. A spoke has no input for a route domain, and a `RouteDomain` tag it supplies is rejected, so it cannot classify its own attachment even as a label.
- Owner verification before routing. The network account approves each attachment by its expected VPC-owner account. The accepter's postcondition compares it with the owner AWS reports, and association, propagation, and static routes all depend on the accepter, so a mismatch stops the apply before anything is routed.
- Production and non-production never route to each other directly. `network-routing` rejects a `propagation_matrix` that lets `prod` into `non-prod` or the reverse, and a static route in one table that targets an attachment of the other. Blackholes are always allowed.
- Segmentation by absence. A route exists only if the matrix or a static route declares it, and every domain that has an attachment needs a matrix entry, even an empty one, so leaving a destination out is a deliberate act.
- Flow logs that can be trusted. All traffic is recorded at one-minute aggregation in the Transit Gateway record format, to a log group encrypted with a rotating customer-managed key and kept for at least a year. Two metric filters count records that lost packets for lack of a route or to a blackhole, and one alarm watches them.
- A RAM share that stays inside the organization. `allow_external_principals` is false, and principals are validated as account IDs or Organization and OU ARNs, never IAM users or roles.
- Plan-time validation of every input, advisory `check` blocks for drift from the accepted design, and contract tests for every branch.

## Quick start

The hub owner, in the Network account:

```hcl
module "hub" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git?ref=<commit-sha>" # v1.0.0

  name            = "platform-use2"
  amazon_side_asn = 64512

  ram_principals = ["111122223333", "444455556666"]

  rejected_traffic_alarm_actions = [aws_sns_topic.network_sre.arn]

  tags = { Owner = "network", CostCenter = "platform" }
}
```

This creates the Transit Gateway with association, propagation, and automatic acceptance disabled, five empty route tables named `platform-use2-<domain>`, the flow log and its encrypted 365-day log group, the alarm, and a RAM share that lets two accounts in the organization see the gateway.

A spoke, in its own account, requests an attachment and reports the ID to the network team:

```hcl
module "attachment" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/vpc-attachment?ref=<commit-sha>" # v1.0.0

  name               = "prod-app-use2"
  transit_gateway_id = "tgw-0123456789abcdef0"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  attachment_key     = "prod-app-use2"
}
```

The network account accepts, verifies, classifies, and routes it:

```hcl
module "routing" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/network-routing?ref=<commit-sha>" # v1.0.0

  route_table_ids          = module.hub.route_table_ids
  approved_account_domains = { "111122223333" = "prod", "444455556666" = "non-prod" }

  attachments = {
    prod-app = { attachment_id = "tgw-attach-0123456789abcdef0", account_id = "111122223333" }
  }

  propagation_matrix = {
    prod       = ["prod", "shared"]
    non-prod   = ["non-prod", "shared"]
    shared     = ["prod", "non-prod", "shared"]
    inspection = ["inspection"]
    on-prem    = ["prod", "non-prod", "shared", "on-prem"]
  }

  static_routes = {
    non-prod-private-supernet = { route_table_domain = "non-prod", destination_cidr_block = "10.0.0.0/8", blackhole = true }
  }
}
```

## The three roles

| Role | Account | Module | Owns | Never does |
| --- | --- | --- | --- | --- |
| Hub owner | Network | root | The Transit Gateway, the route domains, the RAM share, the flow log and alarm. | Attach a spoke VPC. |
| Network account | Network | [`modules/network-routing`](modules/network-routing) | Accepting each attachment, verifying its VPC owner, assigning its route domain, association, propagation, static and blackhole routes. | Accept an attachment from an account it has not approved, or connect `prod` and `non-prod` directly. |
| Spoke | Workload | [`modules/vpc-attachment`](modules/vpc-attachment) | Requesting an attachment for its own VPC under a catalog key. | Choose a route domain, associate, propagate, or accept. |

The hub owner and the network account are usually the same account and often the same Terraform root. They are separate modules so the trust boundary is visible in code and a spoke's code can never reach it.

## Architecture

```text
root (one regional hub)
├── main.tf        aws_ec2_transit_gateway.this; aws_ec2_transit_gateway_route_table.domain["<domain>"]
├── ram.tf         aws_ram_resource_share.this; TGW association; aws_ram_principal_association.approved_principal["<principal>"]
├── flow_logs.tf   KMS key + alias, log group, delivery role and policy, aws_flow_log, two metric filters, alarm
├── locals.tf      RAM principal resolution, KMS/trust/delivery policies, flow-log fields and filter patterns
├── checks.tf      deprecated_ram_principal_arns, ram_principal_arns_ignored, route_domains_cover_adr_0003 (advisory)
└── outputs.tf     transit_gateway, route_table_ids, ram_resource_share_arn, flow_logs
modules/network-routing    terraform_data.network_policy (preconditions); vpc_attachment_accepter, route_table_association,
                           route_table_propagation, route: everything the TGW owner does to an attachment
modules/vpc-attachment     one aws_ec2_transit_gateway_vpc_attachment with no default route table
```

The attachment handshake, and who acts at each step:

1. The hub owner applies the root. It outputs `transit_gateway`, `route_table_ids`, and `ram_resource_share_arn`.
2. RAM exposes the gateway to the approved principals, and only to principals inside the organization.
3. A spoke applies `vpc-attachment`. The attachment is created in `pendingAcceptance`, attached to no route table, and its output is the attachment ID and the catalog key.
4. The network account adds the attachment to its catalog and applies `network-routing`. For each entry it accepts the attachment, checks the reported VPC owner against the approved account, and only then associates the attachment with its account's route domain and propagates it into the destination domains the matrix lists.

Nothing the spoke supplies can influence step 4 except the attachment ID it hands over.

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal-hub`](examples/minimal-hub) | A name and an ASN: every default, five empty route domains, encrypted flow logs, the alarm. |
| [`examples/segmented-domains`](examples/segmented-domains) | The network account: hub plus `network-routing` with explicit associations, a propagation matrix, and a blackhole route. |
| [`examples/spoke-attachment`](examples/spoke-attachment) | A workload account requesting an unclassified attachment with `vpc-attachment`. |
| [`examples/organization-share`](examples/organization-share) | Sharing the hub through RAM with an Organization or with organizational units. |

## Security model

Transit Gateway

- Default route-table association and default propagation are `disable`, and shared attachments are never accepted automatically. Attachments are accepted, associated, and propagated only by the network account through `modules/network-routing`, and the accepter and the spoke attachment both opt out of the default route table as well.
- Encryption support and DNS support are on. Security-group referencing is off, because cross-VPC security-group references would bypass the account-owned policy. Multicast is off, because Transit Gateway flow logs do not record multicast.

Segmentation

- `approved_account_domains` maps a workload account to its one route domain. An attachment from an account that is not in the map is rejected before it is accepted, and the VPC owner AWS reports must equal the account the attachment was approved for.
- `propagation_matrix` is deny by absence: a destination not listed receives no route. Every domain that has an attachment needs an entry, even an empty one.
- `prod` never propagates into `non-prod` (or the reverse), and a static route in one table never targets an attachment of the other (ADR 0003). Blackhole routes tighten isolation and are always allowed.
- `route_table_ids` must give every domain its own route table: two domains that share one table are one domain.

Sharing

- The RAM share sets `allow_external_principals = false`. Principals are 12-digit account IDs or Organization and OU ARNs; IAM users, roles, and wildcards are rejected at plan time. Sharing with an Organization or OU needs RAM sharing with AWS Organizations to be enabled by the management account. Sharing makes the gateway visible; it grants no connectivity.

Flow logs

- All traffic is recorded at 60-second aggregation. The log group is encrypted with a customer-managed key with rotation and a 30-day deletion window; its policy allows the account root and CloudWatch Logs in this Region, only in the encryption context of this hub's log group. Retention is at least 365 days.
- The delivery role can be assumed only by the flow-log service, only for this account and Region (`aws:SourceAccount`, `aws:SourceArn`), and may write only to this hub's log group.
- Transit Gateway flow-log records have no accept/reject action. "Rejected" therefore means dropped by the hub: `packets-lost-no-route` (the deny-by-default case) or `packets-lost-blackhole` (an explicit blackhole route). Each has a metric filter feeding the `Platform/TransitGateway` `TransitGatewayRejectedTraffic` metric, and the alarm sums it over five minutes. Missing data does not alarm. Set `rejected_traffic_alarm_actions` so someone is told.
- The principal that applies the root needs `ec2:*TransitGateway*` and `ec2:CreateFlowLogs`, RAM share management, KMS key and alias management, CloudWatch Logs and alarm management, and IAM role management for `<name>-tgw-flow-logs`, including `iam:PassRole` to `vpc-flow-logs.amazonaws.com`. [tests/integration/iam](tests/integration/iam/integration-permissions-policy.json) lists a concrete set.

Not created here

- VPN, Direct Connect gateway, peering, and Connect attachments and the routing for on-premises networks, Route 53 Resolver rules, and the spoke VPCs and their routes to the gateway. They are separately approved compositions (ADR 0003, ADR 0005) that consume `transit_gateway` and `route_table_ids`.

## Lifecycle notes

- Route tables are keyed by domain (`aws_ec2_transit_gateway_route_table.domain["prod"]`). Adding a domain adds exactly one table; removing one deletes it, which AWS refuses while an association remains, so unassign attachments first.
- RAM principal associations are keyed by principal. Removing one takes effect at once: the principal can no longer see the gateway, but attachments it already created keep working until the network account removes them.
- `ram_principal_arns` is deprecated and removed in v2. `ram_principals` is preferred; when both are set the deprecated input is ignored and a check says so. `ram_principals = null` (the default) falls back to the deprecated input, and an explicit empty set shares with nobody.
- The flow-log record format is fixed by the module. Changing the flow-log fields replaces the flow log; the log group and its history are kept.
- `flow_log_retention_in_days` accepts only the periods CloudWatch Logs supports, all at least 365. The KMS key is scheduled for deletion with a 30-day window when the hub is destroyed.
- Deleting a Transit Gateway waits for every attachment to be gone. Remove `network-routing` and the spokes' attachments first.
- The module reads the partition, Region, and account identity once, to name the log-group ARN in the key policy and the delivery role before the log group exists.
- Three `check` blocks warn without blocking: `deprecated_ram_principal_arns`, `ram_principal_arns_ignored`, and `route_domains_cover_adr_0003`. None fires on the defaults.
- `network-routing` accepts an attachment before it can compare the owner AWS reports with the approved account (there is no earlier API). If they differ, the apply fails, nothing is associated or propagated, and the accepted attachment stays unrouted until you remove it from the catalog and reject it.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/`, `modules/*/tests/`, run by `make test` and by CI) use `mock_provider`: no credentials, nothing created. They cover the secure defaults, every variable validation with `expect_failures`, every precondition (including the ADR 0003 isolation rule in both directions), every check block, the flow-log fields against the AWS Transit Gateway record reference, and the JSON documents the module renders. Assertions that need values known only after apply, such as the wiring between resources and the owner-verification postcondition, run in their own `command = apply` files with explicit `mock_resource` defaults so they cannot leak into the plan runs.
- **Integration suite** (`tests/integration/`, run by `make integration-smoke` or the dispatch-only `integration` workflow) applies one hub with no attachments in **your** account with **your** credentials and region from the environment, asserts what the real APIs report, and destroys it. It is the only test that proves AWS accepts the flow-log record format, the delivery role's trust policy, and the filter patterns. Attachments are billed by the hour and need two accounts, so the handshake is covered by the contract tests only. See [tests/integration/README.md](tests/integration/README.md) for permissions and the GitHub environment contract.

## Design principles

- Single responsibility. The root owns the hub, `network-routing` owns everything the gateway owner does to an attachment, and `vpc-attachment` owns a spoke's request. Concerns are split by file in the root: `main.tf`, `ram.tf`, `flow_logs.tf`, `locals.tf`, `checks.tf`.
- Open/closed. New segments, principals, accounts, attachments, and routes are data: another domain in `route_domains`, another entry in `approved_account_domains`, `attachments`, or `static_routes`. Nothing needs the module edited.
- Liskov substitution. `network-routing` consumes route-table IDs, not the hub module, so a hub and its routing may live in one root or two, and any producer of the same map can replace the hub.
- Interface segregation. A spoke sees six inputs and no routing concept; the network account sees no flow-log concept.
- Dependency inversion. The submodules depend on identifiers (a Transit Gateway ID, route-table IDs, attachment IDs), never on how they were produced.

The full rationale, including what changed from v0.2.0 and what was deliberately deferred, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`. No module declares `configuration_aliases`; a spoke runs with its own provider in its own root, and the examples show the provider blocks.
- One Transit Gateway in one Region per module call. Add a hub per Region; peering between hubs is a separate approved composition.
- The interface is unchanged from v0.2.0. Additions arrive as optional inputs and outputs; the deprecated `ram_principal_arns` input is removed only in v2.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "hub" {
  source = "git::https://github.com/hatan4ik/aws.modules.tgw.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line (for example a 0.2.x fix after 1.0.0 landed on `main`) is cut from that line's commit.

Upgrading from 0.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md); the interface is preserved and the source ref is the only change a consumer must make. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

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
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.blackholed_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.rejected_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.rejected_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_flow_log.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_ram_principal_association.approved_principal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Approved private BGP ASN for the Amazon side of this regional Transit Gateway. | `number` | n/a | yes |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | CloudWatch Logs retention for Transit Gateway Flow Logs. Network evidence is retained for at least one year. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Lowercase Transit Gateway hub name used in resource names and tags. At most 50 characters because the flow-log role is named <name>-tgw-flow-logs and IAM role names are limited to 64. | `string` | n/a | yes |
| <a name="input_ram_principal_arns"></a> [ram\_principal\_arns](#input\_ram\_principal\_arns) | Deprecated compatibility input, removed in v2. Use ram\_principals, which also accepts 12-digit AWS account IDs. Ignored when ram\_principals is set. | `set(string)` | `[]` | no |
| <a name="input_ram_principals"></a> [ram\_principals](#input\_ram\_principals) | AWS account IDs or AWS Organizations organization/OU ARNs permitted to create VPC attachments to this TGW. All must be inside the organization: the share never allows external principals. null falls back to the deprecated ram\_principal\_arns; an empty set shares with nobody. | `set(string)` | `null` | no |
| <a name="input_rejected_traffic_alarm_actions"></a> [rejected\_traffic\_alarm\_actions](#input\_rejected\_traffic\_alarm\_actions) | Optional SNS or incident-management action ARNs notified by the rejected-TGW-traffic alarm. CloudWatch allows at most five. | `set(string)` | `[]` | no |
| <a name="input_rejected_traffic_alarm_threshold"></a> [rejected\_traffic\_alarm\_threshold](#input\_rejected\_traffic\_alarm\_threshold) | Rejected TGW flow-log records (dropped for lack of a route or by a blackhole route) that trigger the five-minute rejected-traffic alarm. | `number` | `1` | no |
| <a name="input_route_domains"></a> [route\_domains](#input\_route\_domains) | Network-owned TGW route domains, one deny-by-default route table each. Attachments are associated later by the separate network-routing module. The default is the five domains of ADR 0003. | `set(string)` | <pre>[<br/>  "prod",<br/>  "non-prod",<br/>  "shared",<br/>  "inspection",<br/>  "on-prem"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and Component tags are computed by the module and cannot be overridden. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_logs"></a> [flow\_logs](#output\_flow\_logs) | Transit Gateway Flow Log, encrypted log group, KMS key, and rejected-traffic alarm identifiers. |
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | RAM resource share ARN used to audit approved TGW attachment principals. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Network-owned route-domain to TGW route-table ID mapping consumed by the separate network-routing module. |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Regional TGW identifiers needed by separately approved network routing, workload attachment, peering, and VPN composition. |
<!-- END_TF_DOCS -->
