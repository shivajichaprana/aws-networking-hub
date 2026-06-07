# ---------------------------------------------------------------------------
# dns-hybrid/main.tf
#
# Route 53 Resolver endpoints for hybrid DNS resolution:
#   - Inbound endpoint  — allows on-premises resolvers to query AWS private
#     hosted zones and internal service records via the VPC.
#   - Outbound endpoint — allows AWS resolvers to forward queries for
#     on-premises domains (e.g., corp.internal) to on-prem DNS servers.
#
# Resolver rules (forwarding rules) are defined in rules.tf.
# Private Hosted Zone associations live in private-hosted-zones.tf.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = var.name
  common_tags = merge(var.tags, {
    Module = "dns-hybrid"
  })
}

# ---------------------------------------------------------------------------
# Security Group — Resolver endpoints
#
# Allows UDP/TCP port 53 from VPC CIDR (inbound endpoint traffic) and from
# on-premises CIDRs (outbound endpoint responses).
# ---------------------------------------------------------------------------

resource "aws_security_group" "resolver" {
  name        = "${local.name_prefix}-resolver-endpoints"
  description = "Route 53 Resolver inbound and outbound endpoint traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "DNS UDP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS TCP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  dynamic "ingress" {
    for_each = length(var.on_prem_cidrs) > 0 ? [1] : []
    content {
      description = "DNS UDP from on-premises networks"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = var.on_prem_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.on_prem_cidrs) > 0 ? [1] : []
    content {
      description = "DNS TCP from on-premises networks"
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = var.on_prem_cidrs
    }
  }

  egress {
    description = "Allow all outbound (resolver queries)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-resolver-endpoints"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Inbound Resolver Endpoint
#
# On-premises DNS forwarders send queries to the IPs assigned to this endpoint.
# One ENI is created per subnet (one per AZ is recommended for HA).
# ---------------------------------------------------------------------------

resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${local.name_prefix}-inbound"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.resolver_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-inbound"
    Direction = "inbound"
  })
}

# ---------------------------------------------------------------------------
# Outbound Resolver Endpoint
#
# Route 53 Resolver uses the IPs of this endpoint as the source when sending
# forwarded queries to on-premises or partner DNS servers.
# ---------------------------------------------------------------------------

resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "${local.name_prefix}-outbound"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.resolver_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-outbound"
    Direction = "outbound"
  })
}
