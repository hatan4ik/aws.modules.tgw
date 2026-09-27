# Advisory checks warn without blocking. None fires on the defaults.

check "deprecated_ram_principal_arns" {
  assert {
    condition     = length(var.ram_principal_arns) == 0
    error_message = "ram_principal_arns is deprecated and will be removed in v2. Move its values to ram_principals, which accepts the same organization and OU ARNs and also 12-digit account IDs."
  }
}

check "ram_principal_arns_ignored" {
  assert {
    condition     = var.ram_principals == null || length(var.ram_principal_arns) == 0
    error_message = "Both ram_principals and the deprecated ram_principal_arns are set. ram_principals wins and ram_principal_arns is ignored, so principals listed only there are not shared. Merge them into ram_principals."
  }
}

check "route_domains_cover_adr_0003" {
  assert {
    condition     = length(setsubtract(local.adr_route_domains, local.route_domains)) == 0
    error_message = "route_domains omits ${join(", ", sort(tolist(setsubtract(local.adr_route_domains, local.route_domains))))}. ADR 0003 assigns every attachment to one of prod, non-prod, shared, inspection, or on-prem; a hub without one of them cannot classify attachments the way the platform expects."
  }
}
