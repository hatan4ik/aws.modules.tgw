mock_provider "aws" {}

variables {
  name            = "test-regional-tgw"
  amazon_side_asn = 64512
  ram_principal_arns = [
    "arn:aws:organizations::111122223333:organization/o-example",
  ]
}

run "plans_explicit_segmented_hub" {
  command = plan

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.domain) == 5
    error_message = "A hub must have the five ADR-defined route domains."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable" && aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "TGW default association and propagation must remain disabled."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.auto_accept_shared_attachments == "disable" && aws_ec2_transit_gateway.this.encryption_support == "enable"
    error_message = "The TGW must not auto-accept attachments and must retain encryption support."
  }
}

run "rejects_public_asn" {
  command = plan

  variables {
    amazon_side_asn = 64496
  }

  expect_failures = [var.amazon_side_asn]
}
