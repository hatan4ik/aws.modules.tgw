mock_provider "aws" {}

variables {
  name               = "test-workload-use1"
  transit_gateway_id = "tgw-0123abcd"
  vpc_id             = "vpc-0123abcd"
  subnet_ids         = ["subnet-0123abcd", "subnet-4567cdef"]
  attachment_key     = "prod-app-use2"
}

run "plans_an_explicit_nondefault_attachment" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.transit_gateway_default_route_table_association == false && aws_ec2_transit_gateway_vpc_attachment.this.transit_gateway_default_route_table_propagation == false
    error_message = "A workload attachment must not join a default TGW route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.appliance_mode_support == "disable"
    error_message = "Workload attachments must not enable appliance mode by default."
  }
}

run "rejects_invalid_attachment_key" {
  command = plan

  variables {
    attachment_key = "INVALID"
  }

  expect_failures = [var.attachment_key]
}
