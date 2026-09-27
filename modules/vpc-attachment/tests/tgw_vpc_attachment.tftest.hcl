# A spoke can only request an unclassified attachment. These tests pin what the
# spoke can and cannot say: no default route table, no route domain, no
# RouteDomain label, and computed tags that the caller cannot override.

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

run "requests_the_attachment_for_the_given_vpc_and_subnets" {
  command = plan

  assert {
    condition = (
      aws_ec2_transit_gateway_vpc_attachment.this.transit_gateway_id == "tgw-0123abcd" &&
      aws_ec2_transit_gateway_vpc_attachment.this.vpc_id == "vpc-0123abcd" &&
      toset(aws_ec2_transit_gateway_vpc_attachment.this.subnet_ids) == toset(["subnet-0123abcd", "subnet-4567cdef"])
    )
    error_message = "The attachment joins exactly the shared TGW, the VPC, and the subnets the spoke names."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.dns_support == "enable" && aws_ec2_transit_gateway_vpc_attachment.this.ipv6_support == "disable"
    error_message = "DNS support is on and IPv6 is off unless a reviewed change says otherwise."
  }
}

run "is_unclassified_by_construction" {
  command = plan

  variables {
    tags = {
      Owner = "workload-team"
    }
  }

  assert {
    condition     = !contains(keys(aws_ec2_transit_gateway_vpc_attachment.this.tags), "RouteDomain")
    error_message = "The attachment must carry no RouteDomain tag; only the network account classifies it."
  }

  assert {
    condition     = toset(keys(output.attachment)) == toset(["id", "attachment_key", "appliance_mode_enable"]) && output.attachment.attachment_key == "prod-app-use2" && output.attachment.appliance_mode_enable == false
    error_message = "The output hands the network account the attachment ID and catalog key and nothing that classifies."
  }
}

run "computes_identifying_tags_and_keeps_caller_tags" {
  command = plan

  variables {
    tags = {
      Owner         = "workload-team"
      Name          = "spoofed-name"
      AttachmentKey = "spoofed-key"
      Component     = "spoofed"
    }
  }

  assert {
    condition = (
      aws_ec2_transit_gateway_vpc_attachment.this.tags["Name"] == "test-workload-use1" &&
      aws_ec2_transit_gateway_vpc_attachment.this.tags["AttachmentKey"] == "prod-app-use2" &&
      aws_ec2_transit_gateway_vpc_attachment.this.tags["Component"] == "tgw-vpc-attachment" &&
      aws_ec2_transit_gateway_vpc_attachment.this.tags["Owner"] == "workload-team"
    )
    error_message = "Name, AttachmentKey, and Component are computed and cannot be overridden; other caller tags are kept."
  }
}

run "enables_appliance_mode_only_when_declared" {
  command = plan

  variables {
    appliance_mode_support = true
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this.appliance_mode_support == "enable" && output.attachment.appliance_mode_enable
    error_message = "A reviewed inspection attachment can enable appliance mode, and the output reports it."
  }
}

run "accepts_the_documented_edges" {
  command = plan

  variables {
    name           = "abc"
    attachment_key = "a-63-characters-long-key-0123456789-0123456789-0123456789-0123"
    subnet_ids     = ["subnet-0123abcd", "subnet-4567cdef", "subnet-89abcdef"]
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.this.subnet_ids) == 3
    error_message = "Three subnets, a 3-character name, and a 63-character key are valid."
  }
}

# One failing run per validation.

run "rejects_invalid_attachment_key" {
  command = plan

  variables {
    attachment_key = "INVALID"
  }

  expect_failures = [var.attachment_key]
}

run "rejects_an_attachment_key_that_is_too_short" {
  command = plan

  variables {
    attachment_key = "ab"
  }

  expect_failures = [var.attachment_key]
}

run "rejects_a_name_that_is_not_lowercase" {
  command = plan

  variables {
    name = "Workload-USE1"
  }

  expect_failures = [var.name]
}

run "rejects_a_malformed_transit_gateway_id" {
  command = plan

  variables {
    transit_gateway_id = "tgw-attach-0123abcd"
  }

  expect_failures = [var.transit_gateway_id]
}

run "rejects_a_malformed_vpc_id" {
  command = plan

  variables {
    vpc_id = "subnet-0123abcd"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_a_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0123abcd"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_a_malformed_subnet_id" {
  command = plan

  variables {
    subnet_ids = ["subnet-0123abcd", "vpc-4567cdef"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_a_spoke_authored_route_domain_tag" {
  command = plan

  variables {
    tags = {
      RouteDomain = "prod"
    }
  }

  expect_failures = [var.tags]
}

run "rejects_a_route_domain_tag_in_any_letter_case" {
  command = plan

  variables {
    tags = {
      routedomain = "prod"
    }
  }

  expect_failures = [var.tags]
}

run "rejects_a_reserved_tag_prefix" {
  command = plan

  variables {
    tags = {
      "aws:createdBy" = "someone"
    }
  }

  expect_failures = [var.tags]
}
