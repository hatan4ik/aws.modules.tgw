# Apply-mode contract test, isolated in its own file because run blocks in one
# file share state. The mock provider reports a VPC owner that is NOT the
# account the network account approved. The accepter's postcondition must fail
# before anything can depend on the attachment: association, propagation, and
# static routes all take the accepter's ID, so none of them can be created.
# ADR 0003: "verify the attachment owner before associating or propagating it".

mock_provider "aws" {
  mock_resource "aws_ec2_transit_gateway_vpc_attachment_accepter" {
    defaults = {
      vpc_owner_id = "999999999999"
    }
  }
}

variables {
  # non-prod has no attachment here; it is present so the catalog uses the
  # ADR 0003 domain names and the isolation_domains_present check stays quiet.
  route_table_ids = {
    prod     = "tgw-rtb-0123abcd"
    non-prod = "tgw-rtb-4567cdef"
    shared   = "tgw-rtb-89abcdef"
  }

  approved_account_domains = {
    "111122223333" = "prod"
  }

  attachments = {
    prod-app = {
      attachment_id = "tgw-attach-0123abcd"
      account_id    = "111122223333"
    }
  }

  propagation_matrix = {
    prod   = ["prod", "shared"]
    shared = ["prod", "shared"]
  }
}

run "blocks_an_attachment_whose_vpc_owner_is_not_the_approved_account" {
  command = apply

  expect_failures = [aws_ec2_transit_gateway_vpc_attachment_accepter.approved]
}
