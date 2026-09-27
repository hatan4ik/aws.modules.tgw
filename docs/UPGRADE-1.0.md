# Upgrading to 1.0.0

## What changed and why

Version 1.0.0 is a hardening and standards release. It **preserves the interface of v0.2.0**: every input, output, and resource address of the root, `modules/network-routing`, and `modules/vpc-attachment` keeps its name, type, and shape. The design accepted in ADR 0003 (deny-by-default route domains, spokes that cannot classify their attachments, a network account that owns domain assignment, encrypted flow logs, a RAM share restricted to approved principals) is unchanged. What v1 adds is enforcement the accepted design already called for, stricter plan-time validation, a corrected flow-log format and alarm, tests, examples, and repository standards. The reasons and the full comparison are in [DESIGN.md](DESIGN.md).

A consumer of v0.2.0 changes **only the ref** in the module `source`. There are no `moved` blocks and no state operations.

## Upgrading from 0.2.0

1. Change the ref in every module block to the 1.0.0 release commit, keeping the tag in a comment:

   ```hcl
   module "hub" {
     source = "git::https://github.com/hatan4ik/aws.modules.tgw.git?ref=<commit-sha>" # v1.0.0
     # inputs unchanged
   }
   ```

   The submodules use the same ref: `git::https://github.com/hatan4ik/aws.modules.tgw.git//modules/network-routing?ref=<commit-sha>` and `//modules/vpc-attachment`.

2. Run `terraform init -upgrade` and `terraform plan`. Expect the differences below and nothing else.

3. Read the plan against this table, then apply.

| Difference in the plan | Cause |
| --- | --- |
| `aws_cloudwatch_log_metric_filter.blackholed_traffic` will be created. | The rejected-traffic alarm now counts blackholed traffic through a second filter that feeds the same metric. |
| `aws_flow_log.transit_gateway` and `aws_cloudwatch_log_metric_filter.rejected_traffic` are updated (`log_format`, `pattern`). | v0.2.0 used field names that do not exist for Transit Gateway flow logs and a filter on `action = REJECT` that a Transit Gateway record never contains. A hub that was never applied has nothing to update. |
| `aws_iam_role.flow_logs` is updated in place (`assume_role_policy`). | The trust policy gained `aws:SourceAccount` and `aws:SourceArn` conditions. |
| `aws_cloudwatch_metric_alarm.rejected_traffic` is updated in place (`alarm_description`). | The description names what the alarm now counts. |
| `aws_ec2_transit_gateway.this` shows no change. | `multicast_support = "disable"` is now explicit but matches the provider default. |

No Transit Gateway, route table, RAM, KMS, or log-group resource is replaced. A hub that was applied from v0.2.0 (the flow-log resources could not have been created) shows the flow-log differences as creates.

## Stricter validation

These reject inputs that were documented as invalid, or that always failed at apply. A call that plans cleanly on 0.2.0 and violates one of them was already broken.

| Module | Input | v1 rule |
| --- | --- | --- |
| root | `name` | 3-50 characters (was 3-63). The flow-log role `<name>-tgw-flow-logs` must fit IAM's 64-character limit. |
| root | `amazon_side_asn` | Must be a whole number in a private range. |
| root | `rejected_traffic_alarm_actions` | ARNs, at most five. |
| root, network-routing, vpc-attachment | `tags` | No reserved `aws:` key prefix. |
| network-routing | `route_table_ids` | Every domain has its own route table: two domains sharing one route-table ID are rejected. |
| network-routing | `attachments` | Keys are 3-63 lowercase letters, digits, and hyphens starting with a letter, the same rule as the spoke's `attachment_key`. |
| network-routing | `static_routes` | Canonical CIDRs (host bits zero); each (`route_table_domain`, `destination_cidr_block`) pair once. |
| network-routing | `propagation_matrix`, `static_routes` | `prod` may not propagate into `non-prod` or the reverse, and a static route in one of those tables may not target an attachment of the other (ADR 0003). |
| vpc-attachment | `name` | 3-63 lowercase letters, digits, and hyphens starting with a letter, as documented. |
| vpc-attachment | `tags` | `RouteDomain` (any letter case) is reserved for the network account and rejected. |

## New advisory checks

Three `check` blocks warn on a plan and never block it: `deprecated_ram_principal_arns` (the deprecated input is in use), `ram_principal_arns_ignored` (both RAM inputs are set, so the deprecated one is ignored), and `route_domains_cover_adr_0003` (a hub that omits one of `prod`, `non-prod`, `shared`, `inspection`, `on-prem`). A call that uses only `ram_principals` and the default `route_domains` sees none of them.

## Upgrading from 0.1.x

0.2.0 already replaced the 0.1.x spoke interface, so read the 0.2.0 column too. Nothing in the platform's `infra/active` consumed 0.1.x or 0.2.0.

| 0.1.x | 1.0.0 |
| --- | --- |
| Root `ram_principal_arns` accepted IAM principal ARNs. | IAM users and roles cannot be shared a Transit Gateway. Use `ram_principals` with 12-digit account IDs or Organization and OU ARNs. `ram_principal_arns` still works for those ARNs and warns. |
| Route domains were a fixed local set of five. | `route_domains` (default: the same five). |
| `vpc-attachment` took `route_domain` and tagged the attachment with it. | The input is gone: a spoke cannot choose a domain. Pass `attachment_key`, the catalog key the network team issues, and report `attachment.id` and the key. The network account assigns the domain in `network-routing` `approved_account_domains`. |
| `vpc-attachment` output `attachment.route_domain`. | `attachment.attachment_key` and `attachment.appliance_mode_enable`. |
| No flow logs or alarm. | Created by the root: KMS key and alias, log group, delivery role and policy, flow log, two metric filters, alarm, and the `flow_logs` output. |
| No `network-routing`. | Add it in the network account to accept and route attachments. |

## Procedure for a hub that is already in use

1. Pin the new ref in a branch and run `terraform plan`; compare it with the tables above.
2. If the plan shows a difference not listed here, stop and open an issue with the plan output redacted.
3. Apply in the Network account. Flow-log delivery starts within a few minutes of the flow log being (re)created.
4. Set `rejected_traffic_alarm_actions` if you have not; the alarm is silent without an action.
5. Run `terraform plan` again and confirm it reports no changes.
6. Spokes upgrade their `vpc-attachment` ref independently; the module change for them is only the stricter `name` and `tags` validation.

## Rolling back

The interface is unchanged, so rolling back is a ref change to the previous release. The additions (the `blackholed_traffic` filter and the trust-policy conditions) are removed by the rollback plan; nothing else needs undoing.
