# ---------------------------------------------------------------------------
# dns-hybrid/outputs.tf
# ---------------------------------------------------------------------------

output "inbound_endpoint_id" {
  description = "ID of the Route 53 Resolver inbound endpoint."
  value       = aws_route53_resolver_endpoint.inbound.id
}

output "inbound_endpoint_ips" {
  description = "List of IP addresses assigned to the inbound Resolver endpoint ENIs. Configure these as forwarders on your on-premises DNS servers."
  value       = aws_route53_resolver_endpoint.inbound.ip_address[*].ip
}

output "outbound_endpoint_id" {
  description = "ID of the Route 53 Resolver outbound endpoint."
  value       = aws_route53_resolver_endpoint.outbound.id
}

output "outbound_endpoint_ips" {
  description = "List of IP addresses assigned to the outbound Resolver endpoint ENIs."
  value       = aws_route53_resolver_endpoint.outbound.ip_address[*].ip
}

output "resolver_security_group_id" {
  description = "ID of the security group attached to the Resolver endpoints."
  value       = aws_security_group.resolver.id
}

output "forwarding_rule_ids" {
  description = "Map of forwarding rule key → Route 53 Resolver rule ID."
  value       = { for k, v in aws_route53_resolver_rule.forward : k => v.id }
}

output "forwarding_rule_arns" {
  description = "Map of forwarding rule key → Route 53 Resolver rule ARN (used for RAM sharing)."
  value       = { for k, v in aws_route53_resolver_rule.forward : k => v.arn }
}

output "private_hosted_zone_ids" {
  description = "Map of PHZ logical name → Route 53 hosted zone ID."
  value       = { for k, v in aws_route53_zone.private : k => v.zone_id }
}

output "private_hosted_zone_name_servers" {
  description = "Map of PHZ logical name → list of name server FQDNs (informational)."
  value       = { for k, v in aws_route53_zone.private : k => v.name_servers }
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share for Resolver rules (null if enable_ram_share = false)."
  value       = var.enable_ram_share ? aws_ram_resource_share.resolver_rules[0].arn : null
}
