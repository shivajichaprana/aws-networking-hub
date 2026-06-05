# ---------------------------------------------------------------------------
# VPC Spoke Module — tgw-attachment.tf
#
# Attaches the spoke VPC to the Transit Gateway and places the attachment
# into the correct TGW route table so that routing isolation is enforced
# at the hub level.
#
# Route table association: exactly one TGW route table is the "lookup" table
#   for traffic entering the TGW from this spoke.
# Route table propagation: the spoke's VPC CIDR is advertised into one or
#   more TGW route tables so other spokes can reach it.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# TGW VPC Attachment
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id

  # Use the dedicated TGW attachment subnets — one per AZ.
  subnet_ids = aws_subnet.tgw[*].id

  # DNS support allows VPC endpoints and Route 53 PHZs to resolve correctly
  # across the TGW boundary.
  dns_support = "enable"

  # IPv6 support — disabled by default; enable if the VPC uses IPv6 CIDRs.
  ipv6_support = "disable"

  # Appliance mode places all traffic from a given source to the same
  # availability zone ENI, ensuring symmetry for stateful appliances.
  appliance_mode_support = var.tgw_appliance_mode_support

  tags = merge(var.tags, {
    Name   = "${var.name}-tgw-attachment"
    VpcId  = aws_vpc.this.id
    Module = "vpc-spoke"
  })
}

# ---------------------------------------------------------------------------
# Route Table Association
#
# Associates this attachment with one TGW route table (the "ingress" table).
# Traffic entering the TGW from this spoke is resolved against this table.
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

# ---------------------------------------------------------------------------
# Route Table Propagation — primary table
#
# Advertises this VPC's CIDR into the same route table it is associated with,
# so other spokes in the same tier can reach it automatically.
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "primary" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

# ---------------------------------------------------------------------------
# Route Table Propagation — additional tables (e.g. shared-services table)
#
# Optional: propagate this spoke's CIDR into extra TGW route tables.
# Useful for shared-services VPCs that must be reachable from all tiers.
# ---------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "extra" {
  for_each = toset(var.tgw_route_table_ids_to_propagate)

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = each.value
}
