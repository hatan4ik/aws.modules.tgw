## Summary

<!-- What changes and why. Link the issue this closes, if any. -->

## Type of change

- [ ] fix: bug fix, non-breaking
- [ ] feat: new input, output, or behaviour, non-breaking
- [ ] breaking: existing callers must change configuration or state
- [ ] docs: documentation only
- [ ] chore: tooling, CI, or dependencies

## Checklist

- [ ] Tests added or updated, and `terraform test` passes in every touched directory
- [ ] `make check` passes locally
- [ ] Docs regenerated with terraform-docs (`make docs`) in every touched directory
- [ ] `CHANGELOG.md` `Unreleased` section updated
- [ ] No new data sources, and no weakening of the deny-by-default model in ADR 0003
- [ ] Breaking changes documented in `docs/UPGRADE-<version>.md`
