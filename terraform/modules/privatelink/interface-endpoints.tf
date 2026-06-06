# ──────────────────────────────────────────────────────────────────────────────
# Interface VPC Endpoints (AWS PrivateLink)
#
# Each interface endpoint provisions one Elastic Network Interface (ENI) per
# subnet. Traffic to the service resolves to the private ENI IP via Route 53
# private DNS — enabling_dns_hostnames and enabling_dns_support must be true
# in the VPC.
#
# Cost note (us-east-1 as of 2024): ~$7.30/month per endpoint-AZ, plus
# $0.01/GB processed. Contrast with a NAT Gateway at ~$32.40/month + $0.045/GB.
# Break-even vs NAT is roughly when service calls account for >15 % of egress.
# ──────────────────────────────────────────────────────────────────────────────

# ── Endpoint Security Group ───────────────────────────────────────────────────
resource "aws_security_group" "endpoints" {
  name        = "vpc-endpoints"
  description = "Allow HTTPS from private subnets to VPC interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "vpc-endpoints-sg"
  })
}

# ── Local: service → endpoint configuration map ───────────────────────────────
locals {
  # Map of logical name → { enabled, service_suffix }
  interface_endpoint_config = {
    ecr_api       = { enabled = var.enable_ecr_api,       service = "ecr.api" }
    ecr_dkr       = { enabled = var.enable_ecr_dkr,       service = "ecr.dkr" }
    sts           = { enabled = var.enable_sts,            service = "sts" }
    kms           = { enabled = var.enable_kms,            service = "kms" }
    secretsmanager = { enabled = var.enable_secretsmanager, service = "secretsmanager" }
    ssm           = { enabled = var.enable_ssm,            service = "ssm" }
    ssmmessages   = { enabled = var.enable_ssmmessages,    service = "ssmmessages" }
    ec2messages   = { enabled = var.enable_ec2messages,    service = "ec2messages" }
    logs          = { enabled = var.enable_logs,           service = "logs" }
    monitoring    = { enabled = var.enable_monitoring,     service = "monitoring" }
    s3_interface  = { enabled = var.enable_s3_interface,   service = "s3" }
  }

  # Only keep the enabled ones
  enabled_interface_endpoints = {
    for k, v in local.interface_endpoint_config : k => v if v.enabled
  }
}

# ── Interface Endpoints ───────────────────────────────────────────────────────
resource "aws_vpc_endpoint" "interface" {
  for_each = local.enabled_interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name    = "${each.value.service}-endpoint"
    Service = each.value.service
    Type    = "Interface"
  })
}
