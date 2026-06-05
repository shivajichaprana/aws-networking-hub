# ---------------------------------------------------------------------------
# VPC Spoke Module — routes.tf
#
# Adds routes in private subnet route tables that send inter-VPC (and any
# additional aggregated RFC-1918) traffic to the Transit Gateway.
#
# Route logic:
#   Private subnets → TGW for all var.inter_vpc_cidrs (default: 10.0.0.0/8)
#   Private subnets → NAT Gateway (or none) for 0.0.0.0/0 internet egress
#   TGW attachment subnets → no default route (TGW-to-TGW traffic is handled
#     by the TGW route tables, not by VPC routes in the attachment subnets)
#
# AWS enforces "most-specific route wins" so adding a default NAT route
# and a narrower TGW route for RFC-1918 correctly steers traffic:
#   10.x.x.x → TGW (more specific)
#   0.0.0.0/0 → NAT Gateway (default)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Inter-VPC routes — private subnets → TGW
#
# One aws_route per (private route table, inter_vpc_cidr) combination.
# Using for_each over a flattened map avoids count-based drift when AZs
# or CIDR lists change independently.
# ---------------------------------------------------------------------------

locals {
  # Build a map keyed by "<az_index>-<cidr_index>" so Terraform can track
  # each route independently without positional instability.
  private_tgw_routes = {
    for pair in flatten([
      for az_idx in range(length(var.availability_zones)) : [
        for cidr_idx, cidr in var.inter_vpc_cidrs : {
          key    = "${az_idx}-${cidr_idx}"
          rt_id  = aws_route_table.private[az_idx].id
          cidr   = cidr
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_route" "private_to_tgw" {
  for_each = length(var.inter_vpc_cidrs) > 0 ? local.private_tgw_routes : {}

  route_table_id         = each.value.rt_id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.transit_gateway_id

  # The TGW attachment must exist before routes can reference the TGW.
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ---------------------------------------------------------------------------
# Internet egress routes — private subnets → NAT Gateway
#
# One NAT Gateway per AZ for HA; each private route table routes its AZ's
# internet-bound traffic to the local NAT Gateway to avoid cross-AZ data
# transfer charges.
# ---------------------------------------------------------------------------

resource "aws_route" "private_nat" {
  count = (var.public_subnets_enabled && var.nat_gateway_enabled) ? length(var.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id

  depends_on = [aws_nat_gateway.this]
}
