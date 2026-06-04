# ---------------------------------------------------------------------------
# Transit Gateway Module — route-tables.tf
#
# Implements routing isolation between prod and non-prod environments:
#
#   Prod route table:
#     - Prod spokes associate into this table and propagate their CIDRs here.
#     - Non-prod spokes do NOT propagate here → prod cannot initiate to non-prod.
#     - A static blackhole route to RFC-1918 can be added to block lateral movement.
#
#   Non-prod route table:
#     - Non-prod spokes associate and propagate here.
#     - Prod spokes do NOT propagate → non-prod cannot reach prod directly.
#
#   Shared-services route table (optional):
#     - For a central-services VPC (DNS, monitoring, AD) reachable from both tiers.
#     - Both prod and non-prod spokes propagate here; services VPC associates here.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-prod"
    Environment = "prod"
    Module      = "tgw"
  })
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-nonprod"
    Environment = "nonprod"
    Module      = "tgw"
  })
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  count              = var.enable_shared_services_route_table ? 1 : 0
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name   = "${var.name}-shared"
    Module = "tgw"
  })
}

# ---------------------------------------------------------------------------
# Prod associations — prod spokes look up routes in the prod table
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.prod

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

# ---------------------------------------------------------------------------
# Non-prod associations
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "nonprod" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.nonprod

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nonprod.id
}

# ---------------------------------------------------------------------------
# Prod propagations — prod spokes advertise their CIDRs to the prod table only
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_to_prod" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.prod

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

# ---------------------------------------------------------------------------
# Non-prod propagations — non-prod spokes advertise only to non-prod table
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "nonprod_to_nonprod" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.nonprod

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nonprod.id
}

# ---------------------------------------------------------------------------
# Shared-services propagations (both tiers → shared table)
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_to_shared" {
  for_each = var.enable_shared_services_route_table ? aws_ec2_transit_gateway_vpc_attachment.prod : {}

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "nonprod_to_shared" {
  for_each = var.enable_shared_services_route_table ? aws_ec2_transit_gateway_vpc_attachment.nonprod : {}

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared[0].id
}

# ---------------------------------------------------------------------------
# Static blackhole routes — drop cross-tier traffic that has no explicit route
#
# Only necessary when both tiers must share a common super-net (e.g. 10.0.0.0/8).
# Set var.blackhole_routes to the CIDRs you want to block in each table.
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route" "prod_blackhole" {
  for_each = toset(var.prod_blackhole_routes)

  destination_cidr_block         = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
  blackhole                      = true
}

resource "aws_ec2_transit_gateway_route" "nonprod_blackhole" {
  for_each = toset(var.nonprod_blackhole_routes)

  destination_cidr_block         = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nonprod.id
  blackhole                      = true
}
