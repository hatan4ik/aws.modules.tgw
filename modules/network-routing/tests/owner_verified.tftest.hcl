# Apply-mode contract test, isolated in its own file because run blocks in one
# file share state. The mock provider reports the VPC owner AWS would return.
# Here it equals the approved account, so acceptance, association,
# propagation, and routes all proceed and the outputs report the verified owner.

mock_provider "aws" {
  mock_resource "aws_ec2_transit_gateway_vpc_attachment_accepter" {
    defaults = {
      vpc_owner_id = "111122223333"
    }
  }
}

variables {
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
    prod-batch = {
      attachment_id = "tgw-attach-4567cdef"
      account_id    = "111122223333"
    }
  }

  propagation_matrix = {
    prod     = ["prod", "shared"]
    non-prod = ["non-prod", "shared"]
    shared   = ["prod", "non-prod", "shared"]
  }

  static_routes = {
    prod-to-batch = {
      route_table_domain     = "shared"
      destination_cidr_block = "10.40.0.0/16"
      blackhole              = false
      target_attachment_key  = "prod-batch"
    }
  }
}

run "proceeds_when_the_vpc_owner_is_the_approved_account" {
  command = apply

  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment_accepter.approved) == 2 && length(aws_ec2_transit_gateway_route_table_association.approved) == 2
    error_message = "A verified attachment is accepted and associated."
  }

  assert {
    condition     = toset(keys(aws_ec2_transit_gateway_route_table_propagation.approved)) == toset(["prod-app:prod", "prod-app:shared", "prod-batch:prod", "prod-batch:shared"])
    error_message = "A verified attachment is propagated only to the destinations the matrix allows."
  }

  assert {
    condition     = output.accepted_attachments["prod-app"].vpc_owner_id == "111122223333" && output.accepted_attachments["prod-app"].route_domain == "prod"
    error_message = "accepted_attachments must report the verified VPC owner and the network-assigned domain."
  }

  assert {
    condition     = toset(keys(output.propagation_ids)) == toset(["prod-app:prod", "prod-app:shared", "prod-batch:prod", "prod-batch:shared"]) && length(aws_ec2_transit_gateway_route.static) == 1
    error_message = "propagation_ids is keyed by attachment and destination domain; the static route is created."
  }
}
