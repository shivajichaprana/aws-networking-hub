# ---------------------------------------------------------------------------
# Transit Gateway Module — main.tf
#
# Creates the Transit Gateway hub with:
#   - Custom Amazon-side ASN
#   - Default route table association/propagation DISABLED (managed explicitly
#     via prod and non-prod route tables in route-tables.tf)
#   - DNS support, multicast disabled
#   - KMS-encrypted CloudWatch flow logs via resource policy
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = var.name
  common_tags = merge(var.tags, {
    Module = "tgw"
  })
}

# ---------------------------------------------------------------------------
# Transit Gateway
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "this" {
  description = "Hub Transit Gateway — ${var.name}"

  amazon_side_asn = var.amazon_side_asn

  # Disable auto-association and auto-propagation so every attachment is
  # explicitly placed into the correct route table (prod or non-prod).
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  dns_support          = var.dns_support
  vpn_ecmp_support     = var.vpn_ecmp_support
  multicast_support    = "disable"
  auto_accept_shared_attachments = var.auto_accept_shared

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

# ---------------------------------------------------------------------------
# Resource Share (optional — enables cross-account spoke attachment)
# ---------------------------------------------------------------------------

resource "aws_ram_resource_share" "tgw" {
  count = var.enable_resource_share ? 1 : 0

  name                      = "${var.name}-tgw-share"
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(local.common_tags, {
    Name = "${var.name}-tgw-share"
  })
}

resource "aws_ram_resource_association" "tgw" {
  count = var.enable_resource_share ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw" {
  for_each = var.enable_resource_share ? toset(var.ram_principal_arns) : []

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
