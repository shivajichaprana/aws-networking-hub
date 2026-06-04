# ---------------------------------------------------------------------------
# Root module — aws-networking-hub
#
# Instantiates the Transit Gateway hub and optional spoke VPCs.
# Each module can also be called independently from examples/.
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.default_tags, {
      Project   = "aws-networking-hub"
      ManagedBy = "Terraform"
    })
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "tgw" {
  source = "./modules/tgw"

  name                       = var.tgw_name
  amazon_side_asn            = var.amazon_side_asn
  dns_support                = var.tgw_dns_support
  vpn_ecmp_support           = var.tgw_vpn_ecmp_support
  auto_accept_shared         = var.tgw_auto_accept_shared
  prod_spoke_vpc_ids         = var.prod_spoke_vpc_ids
  nonprod_spoke_vpc_ids      = var.nonprod_spoke_vpc_ids
  prod_spoke_subnet_ids      = var.prod_spoke_subnet_ids
  nonprod_spoke_subnet_ids   = var.nonprod_spoke_subnet_ids
  tags                       = var.default_tags
}
