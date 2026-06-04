# ---------------------------------------------------------------------------
# Root outputs
# ---------------------------------------------------------------------------

output "transit_gateway_id" {
  description = "ID of the Transit Gateway hub."
  value       = module.tgw.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway hub."
  value       = module.tgw.transit_gateway_arn
}

output "prod_route_table_id" {
  description = "ID of the TGW prod route table."
  value       = module.tgw.prod_route_table_id
}

output "nonprod_route_table_id" {
  description = "ID of the TGW non-prod route table."
  value       = module.tgw.nonprod_route_table_id
}

output "prod_attachment_ids" {
  description = "Map of prod VPC ID → TGW attachment ID."
  value       = module.tgw.prod_attachment_ids
}

output "nonprod_attachment_ids" {
  description = "Map of non-prod VPC ID → TGW attachment ID."
  value       = module.tgw.nonprod_attachment_ids
}
