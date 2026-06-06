output "endpoint_security_group_id" {
  description = "ID of the security group attached to all interface endpoints."
  value       = aws_security_group.endpoints.id
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint (empty string if disabled)."
  value       = var.enable_s3_gateway ? aws_vpc_endpoint.s3_gateway[0].id : ""
}

output "dynamodb_gateway_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint (empty string if disabled)."
  value       = var.enable_dynamodb_gateway ? aws_vpc_endpoint.dynamodb_gateway[0].id : ""
}

output "interface_endpoint_ids" {
  description = "Map of logical name → VPC endpoint ID for all enabled interface endpoints."
  value       = { for k, ep in aws_vpc_endpoint.interface : k => ep.id }
}

output "interface_endpoint_dns_entries" {
  description = "Map of logical name → list of DNS entry objects for each interface endpoint."
  value       = { for k, ep in aws_vpc_endpoint.interface : k => ep.dns_entry }
}
