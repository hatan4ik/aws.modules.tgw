# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

### Added

- Three-phase GitOps route activation contract for cross-account attachments. `modules/network-routing.route_activation_receipts` emits owner-verification, association, and propagation evidence only after the Network-account apply completes. The new `modules/spoke-routes` consumes the exact Phase 1 attachment and Phase 2 receipt, verifies the current workload account owns it, and creates VPC routes only after the barrier passes. This removes the `pendingAcceptance` route race without granting a spoke any network-owner permissions or introducing a polling Lambda.
- `aws_cloudwatch_metric_alarm.flow_log_delivery_stopped` (`<name>-tgw-flow-log-delivery-stopped`): a heartbeat on the flow-log group's `AWS/Logs` `IncomingLogEvents` metric that fires when fewer than one record arrives in an hour, with missing data treated as breaching. The rejected-traffic alarm is `notBreaching` on silence, so before this a broken delivery role, trust policy, or KMS key silently ended the network evidence. It notifies `rejected_traffic_alarm_actions`. A hub with no attachments or no traffic stays in `ALARM` until traffic flows. New output attribute `flow_logs.delivery_stopped_arn`.
- `modules/network-routing`: advisory `check "isolation_domains_present"`, which warns when `route_table_ids` has no `prod` or no `non-prod` key. The ADR 0003 isolation preconditions match those names literally, so a catalog that names its domains differently lost the guard without any message.
- README `Quotas` section: route tables per gateway, routes per gateway, attachments per gateway, and attachments per VPC, documented and deliberately not validated.

### Changed

- **Breaking (no known consumer):** the `vpc-attachment` output attribute `attachment.appliance_mode_enable` is renamed `attachment.appliance_mode_support`, matching the input it reports. No root in the platform repository or any other `hatan4ik` repository reads it. A consumer that does replaces `.appliance_mode_enable` with `.appliance_mode_support`; the value and type are unchanged.
- Comments explain the 30-day (maximum) KMS deletion window on the flow-log key and why `vpn_ecmp_support` stays enabled although the module creates no VPN: the separately approved VPN composition attaches to this gateway and cannot set a gateway-level option, and `enable` is the AWS default.
- `docs/DESIGN.md` records the removal of `ram_principal_arns` and its duplicated validation as a v2 item, with the audit's reasoning.

### Fixed

- `examples/segmented-domains`: `on-prem` propagated into `non-prod` and `shared`, but neither propagated back into `on-prem`, so those domains had a route to on-prem with no return path. Every pair in the example matrix is now symmetric.

## [1.0.0] - 2026-09-27

Hardening and standards release. It preserves the design accepted in ADR 0003 and changes no input, output, or resource address of v0.2.0: a consumer changes only the source ref. [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) lists the stricter validations and the one new resource. The reasoning, and what was deferred to v2, is in [docs/DESIGN.md](docs/DESIGN.md).

### Added

- `modules/network-routing` rejects direct `prod` to `non-prod` connectivity in either direction, as ADR 0003 requires: a `propagation_matrix` that propagates one into the other, and a static route in one table that targets an attachment of the other. Blackhole routes are unaffected.
- A second CloudWatch metric filter, `aws_cloudwatch_log_metric_filter.blackholed_traffic`, so the rejected-traffic alarm counts records that lost packets to a blackhole route as well as to a missing route.
- Advisory `check` blocks `deprecated_ram_principal_arns`, `ram_principal_arns_ignored`, and `route_domains_cover_adr_0003`. None fires on the defaults.
- `aws:SourceAccount` and `aws:SourceArn` conditions on the flow-log role's trust policy, scoped to this account and Region, against the confused-deputy problem.
- Plan-time validation of `rejected_traffic_alarm_actions` (ARNs, at most five), of `tags` (no reserved `aws:` prefix) in all three modules, and of `network-routing` inputs: one distinct route table per domain, attachment catalog keys, canonical static-route CIDRs, and no duplicate (domain, prefix) static route.
- `RouteDomain` is reserved for the network account: `vpc-attachment` rejects it in `tags`, in any letter case.
- `multicast_support = "disable"` stated explicitly on the Transit Gateway.
- Mock-provider contract tests in the root and both submodules covering the secure defaults, every validation and precondition through `expect_failures`, every check, the rendered KMS, trust, and delivery policies, the flow-log fields against the AWS Transit Gateway record reference, and apply-mode wiring and owner-verification tests isolated in their own files.
- Examples `minimal-hub`, `segmented-domains`, `spoke-attachment`, and `organization-share`.
- Credential-driven integration suite `smoke` in `tests/integration/` (one hub with no attachments, created and destroyed), a `make integration-smoke` target, a dispatch-only `integration` workflow that assumes a role through GitHub OIDC from the protected `integration` environment, and the IAM trust and permissions documents the role needs.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, Checkov, Trivy, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

### Changed

- The root module is split by concern into `main.tf`, `ram.tf`, `flow_logs.tf`, `locals.tf`, and `checks.tf`. Resource addresses are identical.
- `name` is limited to 50 characters (was 63). The flow-log role is named `<name>-tgw-flow-logs` and IAM role names are limited to 64 characters, so longer names always failed at apply.
- `amazon_side_asn` must be a whole number.
- `network-routing` preconditions no longer fail with an "invalid index" error for an attachment from an unapproved account; each reports its own message.
- The `terraform-quality` workflow runs the shared `terraform-pipelines` workflow over the root, both submodules, and every example, with a docs drift check. Only the repository root commits `.terraform.lock.hcl`, with checksums for linux and macOS on amd64 and arm64.
- The README is rewritten, including the real release procedure (dispatch `module-release` from the signed tag).

### Fixed

- The Transit Gateway flow-log record format used the VPC field names `transit-gateway-id`, `transit-gateway-attachment-id`, and `action`, which do not exist for Transit Gateway flow logs, so `CreateFlowLogs` would have rejected the first apply. The format now uses only fields from the AWS Transit Gateway flow-log reference (`tgw-id`, `tgw-attachment-id`, `packets-lost-*`, and others).
- The rejected-traffic metric filter matched `action = REJECT`, which a Transit Gateway record never contains, so the alarm could not fire. Filters now match `packets-lost-no-route > 0` and `packets-lost-blackhole > 0`.
- `route_table_ids` accepted two route domains mapped to the same route table, which merges them into one domain.

## [0.2.0] - 2026-09-23

### Added

- `modules/network-routing`: the network account accepts cross-account VPC attachments, verifies the VPC owner, assigns route domains, and creates explicit associations, propagations, and static and blackhole routes. Route domains are chosen by the network account only.
- Encrypted Transit Gateway Flow Log to CloudWatch Logs under a rotating customer-managed key, with a `flow_log_retention_in_days` of at least 365, and a rejected-traffic alarm with `rejected_traffic_alarm_threshold` and `rejected_traffic_alarm_actions`. New output `flow_logs`.
- Inputs `route_domains` and `ram_principals`; `ram_principals` accepts 12-digit account IDs as well as Organization and OU ARNs.
- Contract tests for the RAM principal constraints.
- CI support for modules that declare provider configuration aliases.

### Changed

- **Breaking:** `modules/vpc-attachment` no longer takes `route_domain` and no longer tags the attachment with it. It takes `attachment_key`, a catalog key that is not a route domain, and `appliance_mode_support`. Spokes can no longer choose a route domain.
- `ram_principal_arns` is deprecated in favour of `ram_principals` and no longer accepts IAM principals.

## [0.1.1] - 2026-09-22

### Added

- Generated module reference (inputs and outputs tables) in the READMEs.

## [0.1.0] - 2026-09-22

### Added

- Regional Transit Gateway hub with default route-table association, default propagation, and automatic acceptance disabled, encryption support enabled, and one route table for each of the five ADR 0003 domains (`prod`, `non-prod`, `shared`, `inspection`, `on-prem`).
- AWS RAM resource share that does not allow external principals, with `ram_principal_arns` for approved principals.
- `modules/vpc-attachment` for a workload account's attachment, outside every default route table.
- Contract tests, module versions, and a quality workflow.

[Unreleased]: https://github.com/hatan4ik/aws.modules.tgw/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.tgw/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/hatan4ik/aws.modules.tgw/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/hatan4ik/aws.modules.tgw/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.tgw/releases/tag/v0.1.0
