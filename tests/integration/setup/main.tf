# Disposable prerequisites for the integration suites: a unique hub name and
# identifying tags. The module under test needs nothing else from the account
# (the smoke suite creates a hub with no attachments and no shared principals),
# so this fixture creates no AWS resource; the random suffix keeps concurrent
# runs from colliding on the IAM role, KMS alias, log group, and alarm names
# that derive from the hub name.

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name = "${var.name_prefix}-${random_id.suffix.hex}"

  tags = merge(var.tags, {
    IntegrationTest = "aws.modules.tgw"
    Disposable      = "true"
  })
}
