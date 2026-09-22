locals {
  # ADR 0003 fixes these route domains so a new attachment cannot silently join an implicit default table.
  route_domains = toset(["prod", "non-prod", "shared", "inspection", "on-prem"])

  common_tags = merge(var.tags, {
    Name      = var.name
    Component = "transit-gateway-hub"
  })
}
