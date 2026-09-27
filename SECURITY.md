# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.2.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| 0.1.x | Not supported. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see. Redact account IDs, ARNs, and route-table or attachment IDs.

## What counts

- A segmentation bypass: any input the module claims to reject, or any default, that lets production and non-production reach each other directly, lets a spoke choose or influence its route domain, or lets an attachment be routed before its VPC owner is verified against the approved account.
- A default that weakens the hub: default route-table association or propagation enabled, automatic acceptance of shared attachments, an unencrypted or short-retention flow log, a RAM share that reaches principals outside the organization, or a wildcard principal accepted by a validation.
- A trust-boundary leak: the spoke module gaining an input that classifies, associates, propagates, or accepts, or a caller-supplied tag that overrides a tag the network account computes.
- A weak trust or key policy: a flow-log role assumable by anything but the flow-log service for this account and Region, a KMS key policy that allows more than the account root and CloudWatch Logs for this hub's log group, or a delivery policy broader than this hub's log group.
- Silent blindness: a flow-log format or metric filter that AWS accepts but that cannot record or count dropped traffic, so the alarm cannot fire.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a route domain you chose to connect, or a principal you chose to share with) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: every Transit Gateway default that could route traffic implicitly is disabled, route domains start empty, the network account alone accepts, verifies, classifies, and routes attachments, a spoke can only request an unclassified one, `prod` and `non-prod` cannot be connected directly, the RAM share stays inside the organization, and flow logs are encrypted with a rotating customer-managed key, retained for at least a year, and delivered by a role that only the flow-log service can assume. Every claim is enforced by a validation, a precondition, a postcondition, or a `check` block with a `terraform test` case behind it, and the parts a mock provider cannot judge are covered by the dispatch-only integration suite. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
