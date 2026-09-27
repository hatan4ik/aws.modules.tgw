# Design: aws.modules.tgw v1

Status: accepted 2026-09-27. A hardening-and-standards release of the v0.2.0 module. It preserves the design accepted in ADR 0003 and changes no input, output, or resource address; see [Interface](#interface-unchanged) and [Deferred to v2](#deferred-to-v2).

## Purpose

`aws.modules.tgw` is the regional Transit Gateway hub of the platform network. One root call creates one hub: a Transit Gateway with every default disabled, one deny-by-default route table per route domain, an encrypted Transit Gateway Flow Log with an alarm on dropped traffic, and an AWS RAM share for the accounts or Organization principals that may request attachments. Two submodules cover the two other parties in the attachment handshake:

| Role | Account | Uses | Can do | Cannot do |
| --- | --- | --- | --- | --- |
| Hub owner | Network | root module | Create the TGW, route domains, RAM share, flow logs, alarm. | Attach a spoke VPC. |
| Network account | Network | `modules/network-routing` | Accept a cross-account attachment, verify its VPC owner, assign its route domain, associate it, propagate it, and program static and blackhole routes. | Accept an attachment from an account it did not approve. |
| Spoke | Workload | `modules/vpc-attachment` | Request an **unclassified** attachment for its own VPC. | Choose a route domain, associate, propagate, or accept. |

In practice the hub owner and the network account are the same account and often the same Terraform root; they are separate modules so the trust boundary is visible in code and so a spoke's code can never reach it.

The module deliberately does **not** create VPN attachments, Direct Connect gateway attachments, TGW peering attachments, Connect attachments, Route 53 Resolver rules, or on-premises routing. ADR 0003 and ADR 0005 make those separately approved compositions.

## What is preserved from the ADRs

ADR 0003 (Accepted 2026-09-18) is the contract. Every item below is unchanged in v1 and is asserted positively by a contract test.

| ADR 0003 requirement | Where it lives | v1 |
| --- | --- | --- |
| One TGW per Region, owned by the Network account. | `aws_ec2_transit_gateway.this` | Unchanged. |
| Default route-table association, default propagation, and automatic acceptance of shared attachments are disabled. | TGW arguments; `transit_gateway_default_route_table_*` on the spoke attachment and on the accepter | Unchanged, asserted in all three modules. |
| Attachments associate with exactly one of `prod`, `non-prod`, `shared`, `inspection`, `on-prem`. | `route_domains` (default is the five domains); `approved_account_domains` maps an account to one domain | Unchanged. |
| TGW encryption support enabled. | `encryption_support = "enable"` | Unchanged. |
| Workload code receives an opaque attachment key and cannot select a route domain. | `vpc-attachment` has no route-domain input; `attachment_key` is a catalog key | Unchanged; v1 also rejects a caller-supplied `RouteDomain` tag so a spoke cannot even label its own attachment. |
| The Network-account routing composition accepts and verifies the attachment owner before associating or propagating. | `aws_ec2_transit_gateway_vpc_attachment_accepter.approved` postcondition on `vpc_owner_id`; association and propagation depend on the accepter | Unchanged, and now covered by an apply-mode test that proves a mismatched owner blocks both. |
| Direct `prod` to `non-prod` propagation is rejected in either direction. | `modules/network-routing` | **Implemented in v1.** v0.2.0 only avoided it in its test data; see below. |
| Encrypted flow logs and an alarm feed the Network SRE runbook. | KMS key, log group, flow log, metric filters, alarm | Unchanged interface; **the flow-log format and metric filter were invalid and are corrected**; see below. |
| RAM sharing restricted to approved principals. | `aws_ram_resource_share.this.allow_external_principals = false`; principals are 12-digit account IDs or Organization/OU ARNs | Unchanged. |

## What changed in v1 and why

Everything here is interface-neutral: no input, output, or resource address is renamed, removed, or retyped. Nothing in `infra/active` consumes this module and no Transit Gateway exists yet, so no state migration is involved.

| Area | v0.2.0 behaviour | Problem | v1 |
| --- | --- | --- | --- |
| Flow-log record format | Used the fields `${transit-gateway-id}`, `${transit-gateway-attachment-id}`, and `${action}`. | These are not Transit Gateway flow-log fields. AWS names them `tgw-id` and `tgw-attachment-id`, and Transit Gateway records have no `action` field (they report `packets-lost-*` instead). `CreateFlowLogs` would reject the format, so the first apply would fail. The module had never been applied, and mock-provider tests cannot see this. | The format uses only fields from the AWS Transit Gateway flow-log reference, and a contract test pins every field against an allow-list copied from that reference. |
| Rejected-traffic alarm | The metric filter matched `action = REJECT`. | Even with a valid format the filter could never match, so the alarm would never fire. | Two metric filters count records with `packets-lost-no-route > 0` (deny by absence of a route) and `packets-lost-blackhole > 0` (explicit blackhole). Both emit the existing `Platform/TransitGateway` `TransitGatewayRejectedTraffic` metric, the alarm and its threshold semantics (records per five minutes) are unchanged. Two filters rather than one `||` because CloudWatch documents `||` only within one field of a space-delimited pattern. |
| `prod` to `non-prod` isolation | ADR 0003 says the routing composition must reject it. The test data avoided the pair; nothing rejected it. | A one-line edit to `propagation_matrix` or `static_routes` silently connected production and non-production. | `terraform_data.network_policy` gains preconditions that reject `prod` propagating into `non-prod` (or the reverse), and a static route in the `prod` table that targets a `non-prod` attachment (or the reverse). Blackhole routes are unaffected. |
| Precondition robustness | One precondition indexed `approved_account_domains[account_id]` directly. | An unapproved account produced an "invalid index" error instead of the intended message. | Lookups are guarded; every precondition reports its own message. |
| Route-table catalog | `route_table_ids` accepted two domains mapped to one route table ID (the v0.2.0 test data did exactly that). | Two domains sharing one table are one domain: the segmentation the ADR requires is gone. | Validation requires one distinct route-table ID per domain. |
| Static routes | Duplicate (domain, CIDR) pairs passed validation. | Fails at apply with a provider conflict. | Rejected at plan time. |
| Catalog keys | Attachment keys were unconstrained in `network-routing`. | The spoke validates `attachment_key` (3-63 lowercase); the network account accepted anything, and keys are joined with `:` into propagation keys. | The same rule is enforced on the network side. |
| `name` length | 3-63 characters. | The flow-log role is `<name>-tgw-flow-logs`; IAM caps role names at 64 characters, so names of 51-63 characters passed validation and always failed at apply. | 3-50 characters. |
| Other validations | `amazon_side_asn` accepted non-integers; alarm actions were unchecked; `tags` could contain reserved `aws:` keys; `retention` had a redundant clause. | Late apply-time failures. | Validated at plan time with precise messages. |
| Spoke labelling | `tags` on `vpc-attachment` could carry `RouteDomain`. | The network account ignores attachment tags for routing, but a spoke-authored `RouteDomain = prod` tag on an unclassified attachment misleads operators and auditors. | `RouteDomain` is reserved for the network account and rejected on the spoke. |
| Flow-log role trust | Trust policy named only the service principal. | Confused-deputy exposure; AWS recommends `aws:SourceAccount` and `aws:SourceArn` for flow-log roles. | Both conditions added, scoped to this account and Region (`vpc-flow-log/*`, because the flow log's ID does not exist before the role is needed). |
| TGW multicast | Left to the provider default. | Transit Gateway flow logs do not record multicast, so enabling it would create an unlogged path. | `multicast_support = "disable"` stated explicitly and asserted. |
| Advisory posture | None. | Deprecated input and ADR drift are silent. | `check` blocks warn on the deprecated `ram_principal_arns`, on both RAM inputs being set (the deprecated one is ignored), and on a `route_domains` set that omits an ADR 0003 domain. None fires on the defaults. |
| Layout | `main.tf` held every resource. | Hard to review the flow-log and RAM concerns on their own. | `main.tf` (TGW, route domains), `ram.tf`, `flow_logs.tf`, `checks.tf`. Resource addresses are identical. |
| Tests | Seven runs in total. | Most branches and validations untested. | Contract tests in the root and both submodules cover every validation, precondition, check, and branch, with apply-mode files isolated. See [Testing strategy](#testing-strategy). |
| Repository | A single workflow, no standards, submodule lock files committed. | Not consumable as a product. | Examples, integration suite, standards, README, upgrade guide, changelog, release workflow; only the root commits `.terraform.lock.hcl`. |

## Principles applied

- **Single responsibility.** The root owns the hub; `network-routing` owns everything the TGW owner does to an attachment; `vpc-attachment` owns a spoke's request. No module does two of those.
- **Secure by default.** The defaults are the ADR's: nothing is associated, propagated, or accepted unless the network account says so, and unclassified attachments have no reachability.
- **Deny by absence.** A route exists only if a matrix entry or a static route declares it. `propagation_matrix` requires an entry (possibly empty) for every domain that has an attachment, so omission is an explicit choice.
- **Open/closed.** More domains, principals, accounts, attachments, and routes are data.
- **Interface segregation.** A spoke sees six inputs and no routing concepts.
- **Dependency inversion.** `network-routing` consumes route-table IDs, not the hub module; a hub and its routing may live in one root or two.

## Architecture

```text
root (one regional hub)
├── main.tf        aws_ec2_transit_gateway.this; aws_ec2_transit_gateway_route_table.domain["<domain>"]
├── ram.tf         aws_ram_resource_share.this (no external principals); TGW association; principal associations
├── flow_logs.tf   KMS key + alias; log group; delivery role and policy; aws_flow_log; two metric filters; alarm
├── locals.tf      RAM principal resolution, KMS/trust/delivery policies, flow-log fields, filter patterns
├── checks.tf      advisory checks (deprecation, conflicting RAM inputs, ADR domain drift)
└── outputs.tf     transit_gateway, route_table_ids, ram_resource_share_arn, flow_logs
modules/network-routing    network account: accept, verify owner, associate, propagate, static and blackhole routes
modules/vpc-attachment     spoke account: request an unclassified attachment
```

The handshake:

1. **Hub owner** applies the root. It outputs `transit_gateway.id`, `route_table_ids`, and `ram_resource_share_arn`.
2. The RAM share exposes the TGW to the approved principals. The share refuses principals outside the Organization (`allow_external_principals = false`).
3. **Spoke** applies `vpc-attachment` with the shared TGW ID, its VPC and subnets, and the `attachment_key` the network team gave it. The attachment is created in `pendingAcceptance`, attached to no route table, and its output is the attachment ID.
4. **Network account** records the attachment in its catalog (`attachments`, `approved_account_domains`, `propagation_matrix`) and applies `network-routing`. For each entry it accepts the attachment, checks that the VPC owner is the approved account, and only then associates it with the account's route domain and propagates it to the destination domains the matrix allows.

Nothing the spoke supplies can influence step 4 other than the attachment ID it hands over.

## Interface (unchanged)

The resource addresses, input names and types, and output names and shapes of the three modules are identical to v0.2.0. The only differences a consumer can observe are stricter plan-time validations (listed above), the new preconditions in `network-routing`, and in-place updates on the flow-log resources of a hub that was already applied (v0.2.0's could not have been). [UPGRADE-1.0.md](UPGRADE-1.0.md) is a one-line ref change plus a checklist.

## Security defaults

TGW: default association off, default propagation off, auto-accept off, security-group referencing off, multicast off, DNS and encryption support on. Route tables: one per domain, empty. RAM: internal principals only. Flow logs: all traffic at 60-second aggregation to a log group encrypted with a rotating customer-managed key whose policy allows only the account root and CloudWatch Logs for that one log group; retention at least 365 days; delivery role limited to three actions on that log group and assumable only by the flow-log service for this account and Region. Alarm: five-minute window, `notBreaching` on missing data, actions optional and validated as ARNs.

## Testing strategy

Contract tests use `mock_provider` and need no credentials. Plan-mode files cover defaults, every validation, every precondition and check, and each configuration branch. Assertions that need values known only after apply (wiring between resources, the owner postcondition) run in their own `command = apply` files with explicit `mock_resource` defaults so they cannot leak into plan runs. The dispatch-only integration suite `smoke` (see [tests/integration/README.md](../tests/integration/README.md)) applies a single hub with no attachments in a real account and destroys it; it is the only test that proves AWS accepts the flow-log format and the trust policy, which mock providers cannot.

## Compatibility

Terraform `>= 1.7.0, < 2.0.0`, AWS provider `>= 6.35.0, < 7.0.0` (`encryption_support` needs 6.25). No module declares `configuration_aliases`: the shared quality workflow runs `terraform validate` in every directory, which cannot supply an alias.

## Deferred to v2

Each item would change an input, output, or resource address, or adds surface the accepted design does not need yet. None blocks adoption.

| Item | Why deferred |
| --- | --- |
| Remove `ram_principal_arns` (the deprecated alias of `ram_principals`). | Removing an input is breaking. v1 keeps it and warns through a `check`. |
| Optional `partition`, `region`, and `account_id` inputs that replace the root's three data sources. | New inputs. The root reads the data sources only to build the KMS and delivery-policy ARNs before the log group exists; that fallback is documented and tests override it. |
| Pre-acceptance owner verification with `data.aws_ec2_transit_gateway_vpc_attachment`. | Today the owner is verified by a postcondition after acceptance; association and propagation cannot happen without it, but an attachment from an unexpected account is accepted (unassociated and unrouted) until removed. A data source would refuse earlier at the cost of another API read and a new graph node. |
| Extra outputs: flow-log log-group ARN, TGW owner ID, association and static-route IDs. | New outputs. Consumers can derive them from the existing ones today. |
| Bring-your-own flow-log KMS key or log group; S3 or Firehose flow-log destinations; alarm `ok_actions`. | New optional inputs; the ADR requires encrypted flow logs, which the module already guarantees. |
| Exact `aws:SourceArn` on the flow-log role. | The flow log's ARN depends on the role, so an exact value would create a dependency cycle; the account-and-Region wildcard is the tightest form that can be planned. |
| Making the five ADR domains a closed enum. | It would forbid legitimate extra domains; the `route_domains_cover_adr_0003` check warns on omissions instead. |
| VPN, Direct Connect, peering, and Connect attachments and their routing. | ADR 0003 and ADR 0005 keep them in separate approved compositions. |
