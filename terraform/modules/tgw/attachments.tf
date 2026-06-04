# ---------------------------------------------------------------------------
# Transit Gateway Module — attachments.tf
#
# Manages TGW VPC attachments for:
#   - prod_spoke_vpc_ids   → attached to prod route table
#   - nonprod_spoke_vpc_ids → attached to nonprod route table
#
# Each attachment requires at least one subnet per AZ (TGW ENI subnet).
# Best practice: dedicate /28 subnets per AZ purely for TGW attachments.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Production spoke attachments
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  for_each = toset(var.prod_spoke_vpc_ids)

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value

  # Caller must supply one TGW-dedicated subnet per AZ for this VPC.
  subnet_ids = lookup(var.prod_spoke_subnet_ids, each.value, [])

  # Disable route propagation — routes are managed explicitly in route-tables.tf.
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  # Enable DNS resolution across the attachment.
  dns_support = "enable"

  # Security groups on the TGW ENI (IPv6 not needed in most hub designs).
  ipv6_support = "disable"

  tags = merge(var.tags, {
    Name        = "tgw-attach-prod-${each.value}"
    Environment = "prod"
    Module      = "tgw"
  })

  lifecycle {
    # Prevent accidental detachment — must be explicitly targeted for destroy.
    prevent_destroy = false
  }
}

# ---------------------------------------------------------------------------
# Non-production spoke attachments
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "nonprod" {
  for_each = toset(var.nonprod_spoke_vpc_ids)

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value

  subnet_ids = lookup(var.nonprod_spoke_subnet_ids, each.value, [])

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = merge(var.tags, {
    Name        = "tgw-attach-nonprod-${each.value}"
    Environment = "nonprod"
    Module      = "tgw"
  })
}

# ---------------------------------------------------------------------------
# Route table association and propagation are handled in route-tables.tf
# to keep attachment lifecycle separate from routing concerns.
# ---------------------------------------------------------------------------
