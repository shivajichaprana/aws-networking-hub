# ---------------------------------------------------------------------------
# VPC Spoke Module — outputs.tf
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the spoke VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the spoke VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr" {
  description = "Primary CIDR block of the spoke VPC."
  value       = aws_vpc.this.cidr_block
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "IDs of the public subnets (empty list when public_subnets_enabled = false)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private (workload) subnets."
  value       = aws_subnet.private[*].id
}

output "tgw_subnet_ids" {
  description = "IDs of the TGW attachment subnets."
  value       = aws_subnet.tgw[*].id
}

# ---------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table (null when public_subnets_enabled = false)."
  value       = var.public_subnets_enabled ? aws_route_table.public[0].id : null
}

output "private_route_table_ids" {
  description = "IDs of the private route tables — one per AZ."
  value       = aws_route_table.private[*].id
}

output "tgw_route_table_ids" {
  description = "IDs of the TGW attachment route tables — one per AZ."
  value       = aws_route_table.tgw[*].id
}

# ---------------------------------------------------------------------------
# NAT Gateways
# ---------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways (empty when nat_gateway_enabled = false)."
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs associated with the NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

# ---------------------------------------------------------------------------
# Transit Gateway Attachment
# ---------------------------------------------------------------------------

output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

# ---------------------------------------------------------------------------
# Flow Logs
# ---------------------------------------------------------------------------

output "flow_log_id" {
  description = "ID of the VPC Flow Log resource (null if flow logs disabled)."
  value       = var.enable_flow_logs ? aws_flow_log.this[0].id : null
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC flow logs (null if disabled)."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
