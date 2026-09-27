# Contributing

Thank you for improving `aws.modules.tgw`. This guide covers the toolchain, the local quality gate, how features are tested and where they belong, commit and pull request conventions, and how releases are cut.

The module implements ADR 0003 of the platform: deny-by-default route domains, spokes that cannot classify their own attachments, a network account that owns domain assignment, encrypted flow logs, and a RAM share restricted to approved principals. A change that weakens any of those needs an ADR amendment first; it is not a pull request.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in every README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy. CI runs 3.3.19; older releases miss graph checks. | `pip install checkov==3.3.19` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

`make check` initialises and validates the root, both submodules, every example, and the integration fixture, so the first run downloads the AWS provider once per directory. Set `TF_PLUGIN_CACHE_DIR` to a directory you own to share the download. `terraform test` starts a mock provider for every `run` block and the AWS provider schema is large, so the full suite takes several minutes.

## Integration suites

`tests/integration/` holds a credential-driven suite that applies the module for real and destroys everything afterwards. It is never part of `make check` or the quality pipeline. Run it against your own account before a release that touches resource behaviour, above all the flow-log format, the delivery role, the metric-filter patterns, or the KMS policy, because those are the parts a mock provider cannot judge:

```bash
export AWS_PROFILE=<profile> AWS_REGION=<region>
make integration-smoke   # about five minutes; one hub with no attachments, created and destroyed
```

Keep the suite to a single, short-lived apply with no attachments: attachments are billed by the hour and cross-account acceptance needs a second account. Add a suite only when a feature's correctness depends on the AWS API rather than on rendering. Keep every value derived from the environment or from disposable fixtures the suite creates, and never reference a real account, VPC, or principal. A suite that needs fixtures keeps them in `tests/integration/setup`, which the policy scans exclude.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make validate` | `make init` (`terraform init -backend=false`) followed by `terraform validate` in the root, both submodules, every example, and the integration fixture. |
| `make lint` | `tflint --init` and then `tflint` in every directory with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root and in each submodule. No credentials are needed. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. CI runs `terraform init` before the docs drift check, so a lock file missing the Linux hash gets rewritten and fails that check. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in every directory, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when a README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --framework terraform`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. A skip needs an inline `checkov:skip=` comment, or an entry in `.checkov.yml`, with a reason; there are none today. |
| `make clean` | Removes every `.terraform` directory and every non-root lock file. Run it when you are done. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

Only the repository root commits `.terraform.lock.hcl`. Lock files in submodules and examples are gitignored and must never be added; after any local `terraform init`, run `git diff .terraform.lock.hcl` and discard a degraded change with `git checkout -- .terraform.lock.hcl`. Running `terraform init -test-directory=tests/integration` at the root adds `hashicorp/random` to the root lock; never commit that.

## Test-first workflow

Every behaviour in this module is pinned by a test before it is implemented. Write the failing `run` block first, then the code, then run `make test`.

- Tests live in `tests/*.tftest.hcl` for the root and in `modules/<name>/tests/*.tftest.hcl` for each submodule, one file per concern. Root: `defaults`, `ram`, `flow_logs`, `checks`, `validation`, and `wiring` (apply mode). `network-routing`: `network_routing`, `validation`, `preconditions`, `owner_verified` and `owner_mismatch` (apply mode). `vpc-attachment`: `tgw_vpc_attachment` and `output` (apply mode). Each file starts with `mock_provider "aws" {}` and a `variables` block holding a valid baseline; each `run` overrides only what it exercises.
- Use `command = plan` wherever possible. Nothing here talks to AWS, so tests run without credentials.
- Run blocks in one file share state, so an `apply` run leaks into later `plan` runs in that file. Put every `command = apply` run in a file of its own. Under `apply` with a mock provider, computed strings are random filler: give the identifiers a run compares an explicit `mock_resource` default, as `tests/wiring.tftest.hcl` does.
- The root reads the partition, Region, and account through data sources. Pin them with `mock_data` in the `mock_provider` block so the KMS, trust, and delivery policies can be asserted exactly.
- Validations are tested with `expect_failures`. Point it at the object that carries the check: `[var.name]` for a variable validation, `[terraform_data.network_policy]` for a `network-routing` precondition, `[aws_ec2_transit_gateway_vpc_attachment_accepter.approved]` for its owner postcondition, `[check.deprecated_ram_principal_arns]` for a `check` block. `expect_failures` cannot name an object inside a nested module, so test a submodule rule in the submodule's own `tests/`. A check block that fires fails a run unless the run lists it, so every correct-call run also proves that no check fires.
- Assertions must not depend on unknown values. With a mock provider, computed attributes such as IDs and ARNs are unknown at plan time. Assert on what the module knows by construction: `for_each` keys, tags, configured arguments, rendered JSON, and outputs derived from inputs.
- `||` and `&&` do not short-circuit in Terraform 1.7. Both operands are always evaluated, so `var.x == null || var.x.field > 0` fails when `x` is null. Guard with a conditional instead: `var.x == null ? true : var.x.field > 0`. This applies to validations, preconditions, and test assertions alike.
- Provider numerics can be numbers or strings depending on the attribute: compare `amazon_side_asn` with `tonumber()`. Set-typed attributes need `toset()` in assertions, and `keys()` of an object is a tuple.
- Keep assertion `error_message` text a statement of the guaranteed behaviour. It becomes the documentation of the contract when a test fails.
- Prove that a new test can fail: neutralise the rule it guards and confirm the test reports `Missing expected failure`.

## Where to add a feature

| Concern | Lives in |
| --- | --- |
| The Transit Gateway or its route domains | `main.tf`, with defaults pinned in `tests/defaults.tftest.hcl`. |
| RAM sharing and its principals | `ram.tf`; the principal validation in `variables.tf`; tests in `tests/ram.tftest.hcl`. |
| Flow logs, encryption, the delivery role, the alarm | `flow_logs.tf` and the policy and record-format locals in `locals.tf`; tests in `tests/flow_logs.tftest.hcl` and `tests/wiring.tftest.hcl`. A new flow-log field must appear in the AWS Transit Gateway flow-log reference, and the allow-list in `tests/flow_logs.tftest.hcl` must be updated from that page. |
| Advisory warnings | `checks.tf`, with a test in `tests/checks.tftest.hcl`. A check must not fire on the defaults. |
| What the network account does to an attachment | `modules/network-routing`: inputs and validations in `variables.tf`, cross-input rules as preconditions on `terraform_data.network_policy`, tests in that module's `tests/`. |
| What a spoke can request | `modules/vpc-attachment`. Do not add a route-domain or classification input; that is the ADR 0003 boundary. |
| A new example worth showing | `examples/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and a `README.md` ending in the docs markers; add it to the `terraform-quality` matrix. |

Rules that apply everywhere: every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time; every output has a description; defaults are the secure choice; no input, output, or resource address of a released major version is renamed or removed outside a major release; and no module declares `configuration_aliases`, because the shared quality workflow runs `terraform validate` in every directory and cannot supply an alias (an example that needs a second account declares its provider aliases in its own root configuration).

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the file, submodule, or concern the change touches.

```text
feat(network-routing): reject duplicate static routes
fix(flow-logs): use only documented Transit Gateway record fields
docs: explain sharing the hub with organizational units
test(ram): cover organization and OU principals
feat!: remove the deprecated ram_principal_arns input
```

Append `!` after the type or scope for a breaking change and add a `BREAKING CHANGE:` footer explaining what consumers must do. Breaking changes ship only in a major release with an entry in the upgrade guide.

## Pull request checklist

- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated the README tables in every touched directory.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Breaking changes carry `!`, a `BREAKING CHANGE:` footer, and an update to `docs/UPGRADE-<major>.md`.
- [ ] The change keeps the ADR 0003 model intact, and any change to an input, output, or resource address is a deliberate major-version decision.
- [ ] Examples still initialise and validate; a new feature worth showing has an example.
- [ ] No new default that weakens security.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Run the integration suite (`make integration-smoke`, or dispatch the `integration` workflow) when the release touches resource behaviour.
3. Create a signed annotated tag on the merge commit. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git tag -s vX.Y.Z -m "aws.modules.tgw vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag with `release_tag = vX.Y.Z`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. It verifies the signed tag, formatting, validation, tests, and generated docs, then publishes the GitHub release. Never dispatch it from `main`: the workflow checks that the tag points at the revision it checked out, and a maintenance release of an older line is cut from that line's commit.
5. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.tgw.git?ref=<commit-sha>" # vX.Y.Z
   ```

Tags are never moved or deleted once published. A bad release is followed by a new patch release.
