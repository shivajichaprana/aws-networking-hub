# ──────────────────────────────────────────────────────────────────────────────
# Gateway VPC Endpoints — S3 and DynamoDB
#
# Gateway endpoints are free, highly available, and route traffic through the
# VPC without touching a NAT Gateway or the public internet. They work by
# inserting prefix-list entries into route tables. Always enable these two.
# ──────────────────────────────────────────────────────────────────────────────

# ── S3 Gateway Endpoint ───────────────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3_gateway" {
  count = var.enable_s3_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAllS3"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "s3-gateway-endpoint"
    Type = "Gateway"
  })
}

# ── DynamoDB Gateway Endpoint ─────────────────────────────────────────────────
resource "aws_vpc_endpoint" "dynamodb_gateway" {
  count = var.enable_dynamodb_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAllDynamoDB"
        Effect    = "Allow"
        Principal = "*"
        Action    = "dynamodb:*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "dynamodb-gateway-endpoint"
    Type = "Gateway"
  })
}
