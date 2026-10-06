data "aws_caller_identity" "current" {}

# This resource is the explicit GitOps phase barrier. Its inputs preserve the
# evidence in state, and its preconditions prevent VPC routes from racing a
# pending, unverified, or differently classified cross-account attachment.
resource "terraform_data" "route_activation_barrier" {
  input = {
    attachment = var.attachment
    receipt    = var.network_acceptance_receipt
    routes     = var.routes
  }

  lifecycle {
    precondition {
      condition     = var.network_acceptance_receipt.contract_version == 1
      error_message = "The Network account receipt uses an unsupported contract version; upgrade this spoke-routes module before creating routes."
    }

    precondition {
      condition     = var.network_acceptance_receipt.ready
      error_message = "The Network account has not marked this attachment ready for spoke route activation."
    }

    precondition {
      condition = (
        var.network_acceptance_receipt.attachment_key == var.attachment.attachment_key &&
        var.network_acceptance_receipt.attachment_id == var.attachment.id
      )
      error_message = "The Network account receipt does not describe this spoke attachment key and ID."
    }

    precondition {
      condition     = var.network_acceptance_receipt.vpc_owner_id == data.aws_caller_identity.current.account_id
      error_message = "The Network account receipt was verified for a different VPC-owner AWS account."
    }

    precondition {
      condition     = length(var.network_acceptance_receipt.association_id) > 0
      error_message = "The Network account receipt has no completed route-table association."
    }
  }
}

resource "aws_route" "transit_gateway" {
  for_each = var.routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  transit_gateway_id     = var.network_acceptance_receipt.transit_gateway_id

  depends_on = [terraform_data.route_activation_barrier]
}
