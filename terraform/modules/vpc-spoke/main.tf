# ---------------------------------------------------------------------------
# VPC Spoke Module — main.tf
#
# Provisions a spoke VPC with:
#   - Public subnets (optional, for internet-facing NLBs / NAT Gateways)
#   - Private subnets (workload subnets, route inter-VPC traffic via TGW)
#   - TGW attachment subnets (/28 per AZ — dedicated, no workload traffic)
#   - Internet Gateway (when public_subnets_enabled = true)
#   - NAT Gateways in each public AZ (when nat_gateway_enabled = true)
#   - Flow logs to CloudWatch (optional, default enabled)
#
# The TGW attachment itself lives in tgw-attachment.tf.
# All cross-VPC routing is added to the private route tables in routes.tf.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = var.name
  az_count    = length(var.availability_zones)

  common_tags = merge(var.tags, {
    Module  = "vpc-spoke"
    VpcName = var.name
  })
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  count  = var.public_subnets_enabled ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ---------------------------------------------------------------------------
# Public Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.public_subnets_enabled ? local.az_count : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false # Never auto-assign public IPs; use Elastic IPs or ALBs

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  count  = var.public_subnets_enabled ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_igw" {
  count = var.public_subnets_enabled ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table_association" "public" {
  count = var.public_subnets_enabled ? local.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ---------------------------------------------------------------------------
# Elastic IPs + NAT Gateways (one per AZ for HA)
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = (var.public_subnets_enabled && var.nat_gateway_enabled) ? local.az_count : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = (var.public_subnets_enabled && var.nat_gateway_enabled) ? local.az_count : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Private Subnets (workload subnets)
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
    # EKS/Karpenter convention — tag private subnets for pod scheduling
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------------------------------------------------------------------------
# TGW Attachment Subnets (/28 per AZ — dedicated to TGW ENIs only)
#
# AWS places one elastic network interface (ENI) per AZ into these subnets.
# Keep them small (/28 = 16 addresses, 11 usable) and empty of workloads.
# ---------------------------------------------------------------------------

resource "aws_subnet" "tgw" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw-${var.availability_zones[count.index]}"
    Tier = "tgw-attachment"
  })
}

resource "aws_route_table" "tgw" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw-rt-${var.availability_zones[count.index]}"
    Tier = "tgw-attachment"
  })
}

resource "aws_route_table_association" "tgw" {
  count = local.az_count

  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

# ---------------------------------------------------------------------------
# VPC Flow Logs → CloudWatch Logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix        = "${local.name_prefix}-flow-logs-"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "flow_logs_assume" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "flow-logs-cw"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_cw[0].json
}

data "aws_iam_policy_document" "flow_logs_cw" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/vpc/${local.name_prefix}/*"]
  }
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-logs"
  })

  depends_on = [aws_iam_role_policy.flow_logs]
}
