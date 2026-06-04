# ---------------------------------------------------------------------------
# Transit Gateway Module — outputs.tf
# ---------------------------------------------------------------------------

output "transit_gateway_id" {
  description = "ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "transit_gateway_owner_id" {
  description = "AWS account ID that owns the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.owner_id
}

output "transit_gateway_association_default_route_table_id" {
  description = "ID of the default association route table (disabled — use prod/nonprod tables instead)."
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

# ---------------------------------------------------------------------------
# Route table IDs
# ---------------------------------------------------------------------------

output "prod_route_table_id" {
  description = "ID of the production TGW route table."
  value       = aws_ec2_transit_gateway_route_table.prod.id
}

output "nonprod_route_table_id" {
  description = "ID of the non-production TGW route table."
  value       = aws_ec2_transit_gateway_route_table.nonprod.id
}

output "shared_route_table_id" {
  description = "ID of the shared-services TGW route table (null if not enabled)."
  value       = var.enable_shared_services_route_table ? aws_ec2_transit_gateway_route_table.shared[0].id : null
}

# ---------------------------------------------------------------------------
# Attachment IDs
# ---------------------------------------------------------------------------

output "prod_attachment_ids" {
  description = "Map of production VPC ID → TGW attachment ID."
  value       = { for vpc_id, att in aws_ec2_transit_gateway_vpc_attachment.prod : vpc_id => att.id }
}

output "nonprod_attachment_ids" {
  description = "Map of non-production VPC ID → TGW attachment ID."
  value       = { for vpc_id, att in aws_ec2_transit_gateway_vpc_attachment.nonprod : vpc_id => att.id }
}

# ---------------------------------------------------------------------------
# RAM share ARN
# ---------------------------------------------------------------------------

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share (null if not enabled)."
  value       = var.enable_resource_share ? aws_ram_resource_share.tgw[0].arn : null
}
