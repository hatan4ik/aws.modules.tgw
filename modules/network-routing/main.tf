# The TGW owner, not a spoke workload, accepts, classifies, associates, and
# propagates every cross-account VPC attachment. This is the segmentation trust
# boundary: attachment tags are evidence only and never select a route domain.
resource "terraform_data" "network_policy" {
  input = {
    route_table_ids          = var.route_table_ids
    approved_account_domains = var.approved_account_domains
    attachments              = var.attachments
    propagation_matrix       = var.propagation_matrix
    static_routes            = var.static_routes
  }

  lifecycle {
    precondition {
      condition     = alltrue([for domain in values(var.approved_account_domains) : contains(keys(var.route_table_ids), domain)])
      error_message = "Every approved account domain must name a route table in route_table_ids."
    }

    precondition {
      condition     = alltrue([for attachment in values(var.attachments) : contains(keys(var.approved_account_domains), attachment.account_id)])
      error_message = "Every attachment account must be assigned by approved_account_domains before the network account accepts it."
    }

    precondition {
      condition = alltrue([
        for source_domain, destination_domains in var.propagation_matrix :
        contains(keys(var.route_table_ids), source_domain) &&
        alltrue([for destination_domain in destination_domains : contains(keys(var.route_table_ids), destination_domain)])
      ])
      error_message = "propagation_matrix source and destination domains must exist in route_table_ids."
    }

    precondition {
      condition = alltrue([
        for attachment in values(var.attachments) : contains(keys(var.propagation_matrix), var.approved_account_domains[attachment.account_id])
      ])
      error_message = "Every attachment's network-assigned domain must have a propagation-matrix entry, even when it is empty."
    }

    precondition {
      condition = alltrue([
        for route in values(var.static_routes) :
        contains(keys(var.route_table_ids), route.route_table_domain) &&
        (route.blackhole || contains(keys(var.attachments), route.target_attachment_key == null ? "" : route.target_attachment_key))
      ])
      error_message = "Static routes must use a known route-table domain and target an approved attachment unless blackhole=true."
    }
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "approved" {
  for_each = var.attachments

  transit_gateway_attachment_id                   = each.value.attachment_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(local.common_tags, {
    Name        = each.key
    RouteDomain = local.attachment_domains[each.key]
  })

  lifecycle {
    postcondition {
      condition     = self.vpc_owner_id == each.value.account_id
      error_message = "Attachment ${each.key} belongs to an unexpected VPC-owner account. Do not associate or propagate it."
    }
  }

  depends_on = [terraform_data.network_policy]
}

resource "aws_ec2_transit_gateway_route_table_association" "approved" {
  for_each = var.attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment_accepter.approved[each.key].id
  transit_gateway_route_table_id = var.route_table_ids[local.attachment_domains[each.key]]

  depends_on = [terraform_data.network_policy]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "approved" {
  for_each = local.propagation_specs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment_accepter.approved[each.value.attachment_key].id
  transit_gateway_route_table_id = var.route_table_ids[each.value.destination_domain]

  depends_on = [terraform_data.network_policy]
}

resource "aws_ec2_transit_gateway_route" "static" {
  for_each = var.static_routes

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_route_table_id = var.route_table_ids[each.value.route_table_domain]
  blackhole                      = each.value.blackhole
  transit_gateway_attachment_id  = each.value.blackhole ? null : aws_ec2_transit_gateway_vpc_attachment_accepter.approved[each.value.target_attachment_key].id

  depends_on = [terraform_data.network_policy]
}
