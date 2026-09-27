# One regional hub with every default: five deny-by-default route domains, no
# principals shared with, an encrypted flow log kept for a year, and the
# rejected-traffic alarm. Runs in the Network account.
provider "aws" {
  region = var.region
}

module "hub" {
  source = "../../"

  name            = var.name
  amazon_side_asn = var.amazon_side_asn
  tags            = var.tags
}
