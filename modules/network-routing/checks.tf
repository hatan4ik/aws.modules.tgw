# Advisory checks warn without blocking. None fires on the ADR 0003 domain names.

# The ADR 0003 isolation preconditions in main.tf compare domains by the names in
# local.production_domain and local.non_production_domain. route_table_ids keys
# are free-form, so a catalog that names its domains differently (for example
# "production" and "nonprod") passes every precondition without the isolation
# rule ever applying. Warn here, where the guard lives, so that silent loss is
# visible in every plan that uses this module.
check "isolation_domains_present" {
  assert {
    condition = (
      contains(keys(var.route_table_ids), local.production_domain) &&
      contains(keys(var.route_table_ids), local.non_production_domain)
    )
    error_message = "route_table_ids has no ${join(" and no ", [for domain in [local.production_domain, local.non_production_domain] : "\"${domain}\"" if !contains(keys(var.route_table_ids), domain)])} key. The ADR 0003 prod/non-prod isolation preconditions match only the domain names \"${local.production_domain}\" and \"${local.non_production_domain}\", so they do not protect domains named any other way. Rename the route domains to the ADR 0003 names, or ignore this warning if the hub intentionally has no such domain."
  }
}
