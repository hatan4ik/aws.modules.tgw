# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use the AWS
documentation account `123456789012`, fixed IDs, and placeholder ARNs on
purpose: they prove the module's interface, its validations, and the documents
it renders, not that AWS accepts them. These suites prove the latter.

This matters most for the parts of the hub that only the real API can judge:
the Transit Gateway flow-log record format (AWS rejects field names it does not
know), the flow-log role's trust policy with its `aws:SourceAccount` and
`aws:SourceArn` conditions, and the CloudWatch metric-filter patterns.

Nothing here is tied to an account, region, or landing zone. Credentials and
the region come from the environment; the only prerequisite is a unique hub
name, which [`setup/`](setup/) generates with a random suffix so concurrent
runs never collide. The fixture creates no AWS resource.

| Suite | What it proves | Costs | Needs | Typical time |
| --- | --- | --- | --- | --- |
| `smoke.tftest.hcl` | One hub with the module's defaults and no attachments is accepted by the real APIs: a Transit Gateway with every default disabled and encryption support on, five empty route-domain tables, a RAM share that refuses external principals, a rotating customer-managed key, a one-year encrypted log group, the flow log with the Transit Gateway record format, the delivery role, both drop-counter metric filters, and the rejected-traffic alarm. | A Transit Gateway with no attachments has no hourly charge. The alarm, log group, and role cost nothing measurable in the minutes they exist. The KMS key lingers pending deletion for the module's 30-day window, unusable and free of charge. | credentials, region | about 5 minutes; AWS creates and deletes the gateway asynchronously |

The suite is deliberately a single, short-lived apply with **no attachments, no
VPC, and no shared principals**. Transit Gateway attachments are billed by the
hour and cross-account acceptance needs a second account, so the attachment
handshake (`modules/vpc-attachment` and `modules/network-routing`) is covered by
the contract tests and is not exercised here.

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json)
(replace `<ACCOUNT_ID>`). The EC2 and RAM actions take no useful resource
constraint; the log-group, alarm, KMS-alias, and IAM-role actions are scoped to
names starting with `tgw-it-`, which is what the fixture produces, and
`iam:PassRole` is limited to the flow-log service. `kms:CreateKey` takes no
resource constraint either, so key management is scoped to the account's keys.
The policy was written from the provider's API calls and has not been proven
against a first run: if an action is missing, the failure is an `AccessDenied`
that names it, and the policy should be amended rather than widened to `*`.

`terraform test` runs `tests/` only by default, so these suites never run in
the credential-free quality pipeline. The fixture module is excluded from the
Checkov and Trivy scans (`.checkov.yml`, `trivy.yaml`) because it is
short-lived test scaffolding, not a deployable pattern.

If a run is interrupted, delete what it left behind by name: everything it
creates starts with `tgw-it-` (the Transit Gateway and its route tables carry
the `IntegrationTest = aws.modules.tgw` and `Disposable = true` tags). A
Transit Gateway cannot be deleted while it has attachments; the suite creates
none.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region for the hub under test. |

Dispatch with `gh workflow run integration.yml -f suite=smoke`. Protect the
environment with required reviewers so a run cannot be started from a pull
request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.tgw:environment:integration`.
