# A spoke account can only ask. It requests an attachment for its own VPC to the
# Transit Gateway that the Network account shared with it, under a catalog key
# the network team gave it, and reports the attachment ID. The attachment joins
# no route table and carries no route domain: the Network account accepts,
# classifies, and routes it. Run with credentials for the spoke account.
provider "aws" {
  region = var.region
}

module "attachment" {
  source = "../../modules/vpc-attachment"

  name               = var.name
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  attachment_key     = var.attachment_key
  tags               = var.tags
}
