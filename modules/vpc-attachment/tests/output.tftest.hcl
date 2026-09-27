# Apply-mode contract test, isolated in its own file because run blocks in one
# file share state. The attachment ID is unknown until apply; the mock gives it
# a fixed value so the output can be compared with the resource.

mock_provider "aws" {
  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = {
      id = "tgw-attach-0123456789abcdef0"
    }
  }
}

variables {
  name               = "test-workload-use1"
  transit_gateway_id = "tgw-0123abcd"
  vpc_id             = "vpc-0123abcd"
  subnet_ids         = ["subnet-0123abcd", "subnet-4567cdef"]
  attachment_key     = "prod-app-use2"
}

run "hands_the_network_account_the_attachment_id_and_key" {
  command = apply

  assert {
    condition     = output.attachment.id == "tgw-attach-0123456789abcdef0" && output.attachment.id == aws_ec2_transit_gateway_vpc_attachment.this.id && output.attachment.attachment_key == "prod-app-use2"
    error_message = "The output is the attachment ID plus the catalog key the network account looks it up by."
  }
}
