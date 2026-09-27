# Integration fixtures

Disposable prerequisites for the integration suites in the parent directory: a
unique hub name built from a prefix and a random suffix, and the tags that mark
the hub under test as disposable. The module under test needs nothing else from
the account, so this fixture creates no AWS resource. `terraform test` evaluates
it before the module under test and discards it afterwards. It is not a
deployable pattern and is excluded from policy scans (see `.checkov.yml` and
`trivy.yaml` at the repository root).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix of the disposable hub name; a random suffix is appended so concurrent runs never collide. The flow-log role, KMS alias, log group, and alarm inherit it, which is what the integration IAM policy is scoped to. | `string` | `"tgw-it"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hub under test in addition to the identifying defaults. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Unique name of the hub under test. |
| <a name="output_tags"></a> [tags](#output\_tags) | Identifying tags for the hub under test. |
<!-- END_TF_DOCS -->
